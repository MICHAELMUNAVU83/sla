defmodule Sla.Practice do
  @moduledoc "Practice operations: intake, conflicts, KYC, diary, tasks, workflows, and closing."
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Sla.{Repo, Tracker}

  alias Sla.Practice.{
    CalendarEvent,
    ClientIntake,
    ConflictCheck,
    DeadlineRule,
    DocumentTemplate,
    KycCheck,
    MatterTask,
    WorkflowStep,
    WorkflowTemplate
  }

  def change_intake(intake \\ %ClientIntake{}, attrs \\ %{}),
    do: ClientIntake.changeset(intake, attrs)

  def create_intake(user, attrs),
    do: %ClientIntake{submitted_by_id: user.id} |> ClientIntake.changeset(attrs) |> Repo.insert()

  def list_intakes, do: Repo.all(from i in ClientIntake, order_by: [desc: i.inserted_at])

  def conflict_search(terms, opts \\ []) do
    normalized = terms |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")) |> Enum.uniq()
    excluded_client_id = Keyword.get(opts, :exclude_client_id)

    clients_query =
      from(c in Sla.Clients.Client,
        where: fragment("lower(?) = ANY(?)", c.name, ^Enum.map(normalized, &String.downcase/1)),
        select: %{id: c.id, name: c.name, kind: "client"}
      )

    clients_query =
      if excluded_client_id,
        do: where(clients_query, [c], c.id != ^excluded_client_id),
        else: clients_query

    clients = Repo.all(clients_query)

    parties =
      from(p in Sla.Matters.MatterParty,
        join: m in assoc(p, :matter),
        where: fragment("lower(?) = ANY(?)", p.name, ^Enum.map(normalized, &String.downcase/1)),
        select: %{
          id: p.id,
          name: p.name,
          kind: p.type,
          matter_id: m.id,
          file_number: m.file_number
        }
      )
      |> Repo.all()

    %{clients: clients, parties: parties}
  end

  def record_conflict_check(user, attrs) do
    terms = Map.get(attrs, "search_terms", Map.get(attrs, :search_terms, []))
    terms = if is_binary(terms), do: String.split(terms, ",", trim: true), else: terms
    matches = conflict_search(terms, exclude_client_id: Map.get(attrs, :exclude_client_id))

    result =
      if matches.clients == [] and matches.parties == [], do: "clear", else: "potential_conflict"

    %ConflictCheck{performed_by_id: user.id}
    |> ConflictCheck.changeset(%{
      search_terms: terms,
      matches: matches,
      result: result,
      notes: Map.get(attrs, "notes"),
      performed_at: DateTime.utc_now(:second)
    })
    |> Repo.insert()
  end

  def latest_conflict_check(matter_id),
    do:
      Repo.one(
        from c in ConflictCheck,
          where: c.matter_id == ^matter_id,
          order_by: [desc: c.performed_at],
          limit: 1
      )

  def change_kyc(client_id),
    do:
      KycCheck.changeset(
        Repo.get_by(KycCheck, client_id: client_id) || %KycCheck{client_id: client_id},
        %{}
      )

  def get_kyc(client_id), do: Repo.get_by(KycCheck, client_id: client_id)

  def upsert_kyc(client, user, attrs) do
    check = Repo.get_by(KycCheck, client_id: client.id) || %KycCheck{client_id: client.id}

    check
    |> KycCheck.changeset(attrs)
    |> Ecto.Changeset.put_change(:reviewed_by_id, user.id)
    |> Ecto.Changeset.put_change(:reviewed_at, DateTime.utc_now(:second))
    |> Repo.insert_or_update()
  end

  def change_event(event \\ %CalendarEvent{}, attrs \\ %{}),
    do: CalendarEvent.changeset(event, attrs)

  def list_events(params \\ %{}) do
    CalendarEvent
    |> maybe_event_matter(params["matter_id"] || params[:matter_id])
    |> maybe_event_range(params["from"] || params[:from], params["to"] || params[:to])
    |> preload([:matter, :assigned_to])
    |> order_by([e], asc: e.starts_at)
    |> Repo.all()
  end

  def create_event(user, attrs) do
    Multi.new()
    |> Multi.insert(
      :event,
      %CalendarEvent{created_by_id: user.id} |> CalendarEvent.changeset(attrs)
    )
    |> Multi.run(:deadlines, fn repo, %{event: event} ->
      create_rule_deadlines(repo, user, event)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{event: event}} -> {:ok, event}
      {:error, _, reason, _} -> {:error, reason}
    end
  end

  def court_diary(date) do
    start_at = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    finish = DateTime.add(start_at, 1, :day)

    Repo.all(
      from e in CalendarEvent,
        where:
          e.event_type in ["hearing", "mention"] and e.starts_at >= ^start_at and
            e.starts_at < ^finish,
        preload: [:matter, :assigned_to],
        order_by: [asc: e.starts_at]
    )
  end

  def create_deadline_rule(attrs),
    do: %DeadlineRule{} |> DeadlineRule.changeset(attrs) |> Repo.insert()

  def list_deadline_rules, do: Repo.all(from r in DeadlineRule, where: r.active, order_by: r.name)

  def list_tasks(matter_id),
    do:
      Repo.all(
        from t in MatterTask,
          where: t.matter_id == ^matter_id,
          preload: [:assignee],
          order_by: [asc: t.position, asc: t.due_on]
      )

  def change_task(task \\ %MatterTask{}, attrs \\ %{}), do: MatterTask.changeset(task, attrs)

  def create_task(matter, user, attrs),
    do:
      %MatterTask{matter_id: matter.id, created_by_id: user.id}
      |> MatterTask.changeset(attrs)
      |> Repo.insert()

  def complete_task(id, user) do
    Repo.get!(MatterTask, id)
    |> Ecto.Changeset.change(status: "completed", completed_at: DateTime.utc_now(:second))
    |> Repo.update()
    |> tap(fn {:ok, task} ->
      Tracker.create_activity(Sla.Matters.get_matter!(task.matter_id), user, %{
        action_type: "note",
        note: "Completed task: #{task.title}",
        occurred_at: DateTime.utc_now(:second)
      })
    end)
  end

  def list_workflows,
    do: Repo.all(from w in WorkflowTemplate, where: w.active, preload: [:steps], order_by: w.name)

  def create_workflow(attrs, steps) do
    Repo.transaction(fn ->
      with {:ok, workflow} <-
             %WorkflowTemplate{} |> WorkflowTemplate.changeset(attrs) |> Repo.insert() do
        Enum.with_index(steps, 1)
        |> Enum.each(fn {step, position} ->
          %WorkflowStep{workflow_template_id: workflow.id}
          |> WorkflowStep.changeset(Map.put(step, :position, position))
          |> Repo.insert!()
        end)

        Repo.preload(workflow, :steps)
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def apply_workflow(matter, user, workflow_id, start_on \\ Date.utc_today()) do
    workflow = WorkflowTemplate |> Repo.get!(workflow_id) |> Repo.preload(:steps)

    Repo.transaction(fn ->
      Enum.map(workflow.steps, fn step ->
        {:ok, task} =
          create_task(matter, user, %{
            title: step.title,
            description: step.description,
            due_on: Date.add(start_on, step.days_from_start),
            position: step.position
          })

        task
      end)
    end)
  end

  def create_document_template(attrs),
    do: %DocumentTemplate{} |> DocumentTemplate.changeset(attrs) |> Repo.insert()

  def list_document_templates,
    do: Repo.all(from t in DocumentTemplate, where: t.active, order_by: t.name)

  def assemble_document(template_id, matter) do
    template = Repo.get!(DocumentTemplate, template_id)
    matter = Repo.preload(matter, [:client, :parties, :responsible_advocate])

    values = %{
      "client.name" => matter.client.name,
      "matter.title" => matter.title,
      "matter.file_number" => matter.file_number,
      "matter.court" => matter.court || "",
      "matter.case_number" => matter.case_number || "",
      "matter.parties" => Enum.map_join(matter.parties, ", ", & &1.name),
      "advocate.name" =>
        (matter.responsible_advocate &&
           (matter.responsible_advocate.name || matter.responsible_advocate.email)) || ""
    }

    Enum.reduce(values, template.body, fn {key, value}, body ->
      String.replace(
        body,
        "{{#{key}}}",
        Phoenix.HTML.html_escape(value) |> Phoenix.HTML.safe_to_string()
      )
    end)
  end

  def assemble_pdf(template_id, matter) do
    html = assemble_document(template_id, matter)
    ChromicPDF.print_to_pdf({:html, "<html><body>#{html}</body></html>"})
  end

  def assemble_docx(template_id, matter) do
    text =
      template_id
      |> assemble_document(matter)
      |> String.replace(~r/<[^>]*>/, " ")
      |> String.replace(~r/\s+/, " ")
      |> String.trim()
      |> xml_escape()

    files = [
      {~c"[Content_Types].xml",
       ~S(<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>)},
      {~c"_rels/.rels",
       ~S(<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>)},
      {~c"word/document.xml",
       "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:t xml:space=\"preserve\">#{text}</w:t></w:r></w:p><w:sectPr/></w:body></w:document>"}
    ]

    case :zip.create(~c"assembled.docx", files, [:memory]) do
      {:ok, {_filename, binary}} -> {:ok, binary}
      {:error, reason} -> {:error, reason}
    end
  end

  def add_ethical_wall(matter, user_id, created_by, reason),
    do:
      Repo.insert_all(
        "ethical_walls",
        [
          %{
            matter_id: matter.id,
            user_id: user_id,
            created_by_id: created_by.id,
            reason: reason,
            inserted_at: DateTime.utc_now(:second)
          }
        ],
        on_conflict: :nothing
      )

  def remove_ethical_wall(matter_id, user_id),
    do:
      Repo.delete_all(
        from w in "ethical_walls", where: w.matter_id == ^matter_id and w.user_id == ^user_id
      )

  def walled?(matter_id, user_id),
    do:
      Repo.exists?(
        from w in "ethical_walls", where: w.matter_id == ^matter_id and w.user_id == ^user_id
      )

  def ensure_closing_checklist(matter_id) do
    labels = [
      "All work completed",
      "Final account issued",
      "Client funds reconciled",
      "Original documents returned",
      "Retention date confirmed"
    ]

    now = DateTime.utc_now(:second)

    Repo.insert_all(
      "matter_closing_items",
      Enum.map(
        labels,
        &%{matter_id: matter_id, label: &1, completed: false, inserted_at: now, updated_at: now}
      ),
      on_conflict: :nothing
    )

    list_closing_items(matter_id)
  end

  def list_closing_items(matter_id),
    do:
      Repo.all(
        from i in "matter_closing_items",
          where: i.matter_id == ^matter_id,
          select: %{id: i.id, label: i.label, completed: i.completed},
          order_by: i.id
      )

  def toggle_closing_item(id, user) do
    item =
      Repo.one!(
        from i in "matter_closing_items",
          where: i.id == ^id,
          select: %{id: i.id, completed: i.completed}
      )

    now = DateTime.utc_now(:second)

    Repo.update_all(from(i in "matter_closing_items", where: i.id == ^id),
      set: [
        completed: !item.completed,
        completed_by_id: user.id,
        completed_at: if(item.completed, do: nil, else: now),
        updated_at: now
      ]
    )
  end

  def archive_matter(matter, retention_until) do
    if Enum.all?(ensure_closing_checklist(matter.id), & &1.completed) do
      matter
      |> Ecto.Changeset.change(
        status: "archived",
        closed_on: matter.closed_on || Date.utc_today(),
        retention_until: retention_until,
        archived_at: DateTime.utc_now(:second)
      )
      |> Repo.update()
    else
      {:error, :incomplete_closing_checklist}
    end
  end

  def sync_event(provider, access_token, %CalendarEvent{} = event)
      when provider in [:google, :outlook] do
    {url, body} = calendar_request(provider, event)

    case Req.post(url, auth: {:bearer, access_token}, json: body) do
      {:ok, %{status: status, body: response}} when status in 200..299 -> {:ok, response}
      {:ok, response} -> {:error, {:calendar_api, response.status, response.body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_rule_deadlines(repo, user, event) do
    rules =
      repo.all(
        from r in DeadlineRule, where: r.active and r.trigger_event_type == ^event.event_type
      )

    Enum.each(rules, fn rule ->
      due = add_days(DateTime.to_date(event.starts_at), rule.days, rule.business_days)
      starts_at = DateTime.new!(due, ~T[09:00:00], "Etc/UTC")

      repo.insert!(%CalendarEvent{
        matter_id: event.matter_id,
        created_by_id: user.id,
        assigned_to_id: event.assigned_to_id,
        title: rule.name,
        event_type: rule.result_event_type,
        starts_at: starts_at,
        all_day: true,
        notes: "Automatically generated from #{event.title}"
      })

      if event.matter_id && event.assigned_to_id,
        do:
          Tracker.create_bring_up(%{
            matter_id: event.matter_id,
            assignee_id: event.assigned_to_id,
            created_by_id: user.id,
            due_on: due,
            note: rule.name
          })
    end)

    {:ok, length(rules)}
  end

  defp add_days(date, days, false), do: Date.add(date, days)

  defp add_days(date, days, true),
    do:
      Stream.iterate(Date.add(date, 1), &Date.add(&1, 1))
      |> Stream.filter(&(Date.day_of_week(&1) <= 5))
      |> Enum.at(days - 1)

  defp maybe_event_matter(query, nil), do: query
  defp maybe_event_matter(query, id), do: where(query, [e], e.matter_id == ^id)
  defp maybe_event_range(query, nil, nil), do: query
  defp maybe_event_range(query, from, nil), do: where(query, [e], e.starts_at >= ^from)
  defp maybe_event_range(query, nil, to), do: where(query, [e], e.starts_at <= ^to)

  defp maybe_event_range(query, from, to),
    do: where(query, [e], e.starts_at >= ^from and e.starts_at <= ^to)

  defp calendar_request(:google, event),
    do:
      {"https://www.googleapis.com/calendar/v3/calendars/primary/events",
       %{
         summary: event.title,
         location: event.location,
         description: event.notes,
         start: %{dateTime: event.starts_at},
         end: %{dateTime: event.ends_at || DateTime.add(event.starts_at, 1, :hour)}
       }}

  defp calendar_request(:outlook, event),
    do:
      {"https://graph.microsoft.com/v1.0/me/events",
       %{
         subject: event.title,
         body: %{contentType: "text", content: event.notes || ""},
         location: %{displayName: event.location || ""},
         start: %{dateTime: DateTime.to_iso8601(event.starts_at), timeZone: "UTC"},
         end: %{
           dateTime:
             DateTime.to_iso8601(event.ends_at || DateTime.add(event.starts_at, 1, :hour)),
           timeZone: "UTC"
         }
       }}

  defp xml_escape(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
