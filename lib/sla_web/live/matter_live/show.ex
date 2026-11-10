defmodule SlaWeb.MatterLive.Show do
  use SlaWeb, :live_view
  alias Sla.{Accounts, Billing, Documents, Matters, Practice, Tracker}
  alias Sla.Tracker.FileActivity

  def mount(%{"id" => id}, _session, socket) do
    matter = Matters.get_matter_for_user!(id, socket.assigns.current_scope.user)
    if connected?(socket), do: Tracker.subscribe()

    {:ok,
     socket
     |> assign(
       matter: matter,
       tab: "overview",
       activity_form: activity_form(),
       users: Accounts.list_users(),
       fee_form:
         to_form(
           Billing.change_fee_agreement(
             Billing.get_fee_agreement(matter.id) || %Sla.Billing.FeeAgreement{}
           ),
           as: :fee
         ),
       time_form: to_form(Billing.change_time_entry(%{date: Date.utc_today()}), as: :time_entry),
       disbursement_form:
         to_form(Billing.change_disbursement(%{date: Date.utc_today()}), as: :disbursement),
       financials: Billing.matter_summary(matter.id),
       wip: Billing.list_unbilled(matter.id),
       task_form: to_form(Practice.change_task(), as: :task),
       event_form:
         to_form(Practice.change_event(%Sla.Practice.CalendarEvent{matter_id: matter.id}),
           as: :event
         ),
       tasks: Practice.list_tasks(matter.id),
       events: Practice.list_events(%{matter_id: matter.id}),
       workflows: Practice.list_workflows(),
       workflow_form: to_form(%{"id" => ""}, as: :workflow),
       document_templates: Practice.list_document_templates()
     )
     |> stream(:activities, Tracker.list_activities(matter.id))
     |> stream(
       :documents,
       Documents.list_documents(socket.assigns.current_scope.user, %{matter_id: matter.id})
     )}
  end

  def handle_event("tab", %{"tab" => tab}, socket), do: {:noreply, assign(socket, :tab, tab)}

  def handle_event("save-task", %{"task" => attrs}, socket) do
    case Practice.create_task(socket.assigns.matter, socket.assigns.current_scope.user, attrs) do
      {:ok, _task} ->
        {:noreply,
         assign(socket,
           tasks: Practice.list_tasks(socket.assigns.matter.id),
           task_form: to_form(Practice.change_task(), as: :task)
         )
         |> put_flash(:info, "Task added.")}

      {:error, changeset} ->
        {:noreply, assign(socket, task_form: to_form(changeset, as: :task))}
    end
  end

  def handle_event("complete-task", %{"id" => id}, socket) do
    {:ok, _} = Practice.complete_task(id, socket.assigns.current_scope.user)
    {:noreply, assign(socket, tasks: Practice.list_tasks(socket.assigns.matter.id))}
  end

  def handle_event("apply-workflow", %{"workflow" => %{"id" => id}}, socket) do
    {:ok, _} =
      Practice.apply_workflow(socket.assigns.matter, socket.assigns.current_scope.user, id)

    {:noreply,
     assign(socket, tasks: Practice.list_tasks(socket.assigns.matter.id))
     |> put_flash(:info, "Workflow checklist created.")}
  end

  def handle_event("save-event", %{"event" => attrs}, socket) do
    attrs = Map.put(attrs, "matter_id", socket.assigns.matter.id)

    case Practice.create_event(socket.assigns.current_scope.user, attrs) do
      {:ok, _event} ->
        {:noreply,
         assign(socket,
           events: Practice.list_events(%{matter_id: socket.assigns.matter.id}),
           event_form:
             to_form(
               Practice.change_event(%Sla.Practice.CalendarEvent{
                 matter_id: socket.assigns.matter.id
               }),
               as: :event
             )
         )
         |> put_flash(:info, "Diary event added.")}

      {:error, changeset} ->
        {:noreply, assign(socket, event_form: to_form(changeset, as: :event))}
    end
  end

  def handle_event("save-fee", %{"fee" => attrs}, socket) do
    case Billing.upsert_fee_agreement(socket.assigns.matter, attrs) do
      {:ok, fee} ->
        {:noreply,
         socket
         |> assign(fee_form: to_form(Billing.change_fee_agreement(fee), as: :fee))
         |> put_flash(:info, "Fee agreement saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, fee_form: to_form(changeset, as: :fee))}
    end
  end

  def handle_event("save-time", %{"time_entry" => attrs}, socket) do
    case Billing.create_time_entry(
           socket.assigns.matter,
           socket.assigns.current_scope.user,
           attrs
         ) do
      {:ok, _} ->
        {:noreply, refresh_billing(socket) |> put_flash(:info, "Time entry added.")}

      {:error, changeset} ->
        {:noreply, assign(socket, time_form: to_form(changeset, as: :time_entry))}
    end
  end

  def handle_event("save-disbursement", %{"disbursement" => attrs}, socket) do
    case Billing.create_disbursement(socket.assigns.matter, attrs) do
      {:ok, _} ->
        {:noreply, refresh_billing(socket) |> put_flash(:info, "Disbursement added.")}

      {:error, changeset} ->
        {:noreply, assign(socket, disbursement_form: to_form(changeset, as: :disbursement))}
    end
  end

  def handle_event("create-invoice", _, socket) do
    case Billing.create_invoice_from_wip(socket.assigns.current_scope.user, socket.assigns.matter) do
      {:ok, _} ->
        {:noreply, refresh_billing(socket) |> put_flash(:info, "Draft invoice created.")}

      {:error, :no_unbilled_work} ->
        {:noreply, put_flash(socket, :error, "There is no unbilled work.")}

      {:error, _, reason, _} ->
        {:noreply, put_flash(socket, :error, "Could not create invoice: #{inspect(reason)}")}
    end
  end

  def handle_event("log-activity", %{"activity" => attrs}, socket) do
    bring_up = bring_up_attrs(attrs, socket.assigns.current_scope.user.id)

    clean_attrs =
      Map.drop(attrs, ["bring_up_in", "custom_due_on", "assignee_id", "bring_up_note"])

    case Tracker.create_activity(
           socket.assigns.matter,
           socket.assigns.current_scope.user,
           clean_attrs,
           bring_up
         ) do
      {:ok, {activity, _}} ->
        {:noreply,
         socket
         |> assign(
           matter:
             Matters.get_matter_for_user!(
               socket.assigns.matter.id,
               socket.assigns.current_scope.user
             ),
           activity_form: activity_form(),
           tab: "activity"
         )
         |> stream_insert(:activities, activity, at: 0)
         |> put_flash(:info, "Activity logged.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :activity_form, to_form(changeset, as: :activity))}
    end
  end

  def handle_info({:activity_created, activity}, socket)
      when activity.matter_id == socket.assigns.matter.id,
      do:
        {:noreply,
         socket
         |> assign(
           matter:
             Matters.get_matter_for_user!(activity.matter_id, socket.assigns.current_scope.user)
         )
         |> stream_insert(:activities, activity, at: 0)}

  def handle_info(_, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.page_header title={@matter.title} eyebrow={@matter.file_number}>
        <:actions>
          <.link id="edit-matter" navigate={~p"/matters/#{@matter}/edit"} class="btn-secondary"><.icon
            name="hero-pencil-square"
            class="size-4"
          /> Edit file</.link>
        </:actions>
      </.page_header>
      <div id="latest-action" class="latest-banner">
        <div class="latest-icon"><.icon name="hero-bolt" class="size-5" /></div><div>
          <p class="text-xs font-bold uppercase tracking-widest text-amber-700">Latest action</p><p class="text-sm font-medium text-slate-700">
            {@matter.last_activity_summary ||
              "No activity logged yet — the file is ready for its first update."}
          </p>
        </div>
      </div>
      <div class="detail-grid">
        <div class="detail-card">
          <span>Client</span><strong><.link navigate={~p"/clients/#{@matter.client}"}>{@matter.client.name}</.link></strong>
        </div><div class="detail-card">
          <span>Responsible</span><strong>{(@matter.responsible_advocate &&
                                              (@matter.responsible_advocate.name ||
                                                 @matter.responsible_advocate.email)) || "Unassigned"}</strong>
        </div><div class="detail-card">
          <span>Status</span><strong>{String.capitalize(@matter.status)}</strong>
        </div>
      </div>
      <nav id="matter-tabs" class="tabs">
        <button
          :for={tab <- ~w(overview activity documents billing tasks calendar)}
          id={"matter-tab-#{tab}"}
          phx-click="tab"
          phx-value-tab={tab}
          class={["tab", @tab == tab && "tab-active"]}
        >{String.capitalize(tab)}</button>
      </nav>
      <section id={"matter-#{@tab}-panel"} class="content-card">
        <%= cond do %>
          <% @tab == "overview" -> %>
            <dl class="definition-grid">
              <div>
                <dt>Practice area</dt><dd>{humanize(@matter.practice_area)}</dd>
              </div><div>
                <dt>Opened</dt><dd>{Calendar.strftime(@matter.opened_on, "%d %b %Y")}</dd>
              </div><div>
                <dt>Court</dt><dd>{@matter.court || "—"}</dd>
              </div><div>
                <dt>Case number</dt><dd>{@matter.case_number || "—"}</dd>
              </div>
            </dl>
          <% @tab == "activity" -> %>
            <div class="activity-workspace">
              <.form
                for={@activity_form}
                id="activity-form"
                phx-submit="log-activity"
                class="activity-form"
              >
                <div class="form-grid">
                  <.input
                    field={@activity_form[:action_type]}
                    type="select"
                    label="Action"
                    options={Enum.map(FileActivity.action_types(), &{humanize(&1), &1})}
                  /><.input field={@activity_form[:occurred_at]} type="datetime-local" label="When" />
                </div><.input
                  field={@activity_form[:note]}
                  type="textarea"
                  label="What happened?"
                  required
                /><div class="form-grid">
                  <.input
                    field={@activity_form[:bring_up_in]}
                    type="select"
                    label="Bring up"
                    options={[
                      {"No reminder", ""},
                      {"Tomorrow", "1"},
                      {"In 3 days", "3"},
                      {"In 7 days", "7"},
                      {"In 14 days", "14"},
                      {"In 30 days", "30"},
                      {"Custom date", "custom"}
                    ]}
                  /><.input field={@activity_form[:custom_due_on]} type="date" label="Custom date" />
                </div><div class="form-grid">
                  <.input
                    field={@activity_form[:assignee_id]}
                    type="select"
                    label="Assign reminder to"
                    options={Enum.map(@users, &{&1.name || &1.email, &1.id})}
                    prompt="Myself"
                  /><.input field={@activity_form[:bring_up_note]} label="Reminder note (optional)" />
                </div><div class="form-actions">
                  <.button id="log-activity" class="btn-primary">Log activity</.button>
                </div>
              </.form><div id="activity-timeline" phx-update="stream" class="timeline">
                <div id="activity-timeline-empty" class="empty-state hidden only:block">
                  No activity has been logged.
                </div><article
                  :for={{id, activity} <- @streams.activities}
                  id={id}
                  class="timeline-item"
                >
                  <div class="timeline-dot"></div><div>
                    <div class="timeline-heading">
                      <strong>{humanize(activity.action_type)}</strong><time>{Calendar.strftime(
                        activity.occurred_at,
                        "%d %b %Y, %H:%M"
                      )}</time>
                    </div><p>{activity.note}</p><span>{activity.user.name || activity.user.email}</span>
                  </div>
                </article>
              </div>
            </div>
          <% @tab == "documents" -> %>
            <div class="tab-toolbar">
              <p>Files grouped under this matter.</p><.link
                navigate={~p"/documents?matter_id=#{@matter.id}"}
                class="btn-primary"
              >Open document workspace</.link>
            </div><div id="matter-documents" phx-update="stream" class="document-grid">
              <div id="matter-documents-empty" class="empty-state hidden only:block">
                No documents filed yet.
              </div><.link
                :for={{id, document} <- @streams.documents}
                id={id}
                navigate={~p"/documents/#{document}"}
                class="document-card"
              ><div class="document-icon"><.icon name="hero-document-text" class="size-6" /></div><div>
                <h3>{document.title}</h3><p>{document.category.name}</p><span>Version {document.current_version.version_no}</span>
              </div></.link>
            </div>
          <% @tab == "billing" -> %>
            <div id="matter-financial-summary" class="detail-grid">
              <div class="detail-card">
                <span>Billed</span><strong>KES {Decimal.round(@financials.billed, 2)}</strong>
              </div>
              <div class="detail-card">
                <span>Paid</span><strong>KES {Decimal.round(@financials.paid, 2)}</strong>
              </div>
              <div class="detail-card">
                <span>Outstanding</span><strong>KES {Decimal.round(@financials.outstanding, 2)}</strong>
              </div>
            </div>
            <div class="grid gap-6 xl:grid-cols-3">
              <.form
                for={@fee_form}
                id="fee-agreement-form"
                phx-submit="save-fee"
                class="activity-form"
              >
                <h3 class="font-bold">Fee agreement</h3>
                <.input
                  field={@fee_form[:type]}
                  type="select"
                  label="Structure"
                  options={Enum.map(Sla.Billing.FeeAgreement.types(), &{humanize(&1), &1})}
                />
                <.input field={@fee_form[:amount]} type="number" step="0.01" label="Agreed amount" />
                <.input field={@fee_form[:currency]} label="Currency" />
                <.input field={@fee_form[:terms]} type="textarea" label="Terms" />
                <.button id="save-fee-agreement" class="btn-primary">Save agreement</.button>
              </.form>
              <.form
                for={@time_form}
                id="time-entry-form"
                phx-submit="save-time"
                class="activity-form"
              >
                <h3 class="font-bold">Time entry</h3>
                <.input field={@time_form[:date]} type="date" label="Date" />
                <.input field={@time_form[:minutes]} type="number" label="Minutes" />
                <.input field={@time_form[:rate]} type="number" step="0.01" label="Hourly rate" />
                <.input field={@time_form[:description]} label="Description" />
                <.input field={@time_form[:billable]} type="checkbox" label="Billable" />
                <.button id="save-time-entry" class="btn-primary">Add time</.button>
              </.form>
              <.form
                for={@disbursement_form}
                id="disbursement-form"
                phx-submit="save-disbursement"
                class="activity-form"
              >
                <h3 class="font-bold">Disbursement</h3>
                <.input field={@disbursement_form[:date]} type="date" label="Date" />
                <.input field={@disbursement_form[:type]} label="Type" />
                <.input field={@disbursement_form[:description]} label="Description" />
                <.input field={@disbursement_form[:amount]} type="number" step="0.01" label="Amount" />
                <.input
                  field={@disbursement_form[:vat_applicable]}
                  type="checkbox"
                  label="VAT applicable"
                />
                <.button id="save-disbursement" class="btn-primary">Add expense</.button>
              </.form>
            </div>
            <div id="unbilled-wip" class="mt-6 tab-toolbar">
              <p>
                {length(elem(@wip, 0))} time entries and {length(elem(@wip, 1))} disbursements ready to bill.
              </p>
              <.button id="create-wip-invoice" phx-click="create-invoice" class="btn-primary">Create draft invoice</.button>
            </div>
          <% @tab == "tasks" -> %>
            <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
              <div id="matter-task-list" class="space-y-3">
                <p :if={@tasks == []} id="matter-tasks-empty" class="empty-copy">No tasks yet.</p>
                <article
                  :for={task <- @tasks}
                  id={"matter-task-#{task.id}"}
                  class="detail-card flex items-center justify-between gap-4"
                >
                  <div>
                    <strong>{task.title}</strong><span>{task.due_on || "No due date"} · {humanize(
                      task.status
                    )}</span>
                  </div>
                  <button
                    :if={task.status != "completed"}
                    id={"complete-task-#{task.id}"}
                    phx-click="complete-task"
                    phx-value-id={task.id}
                    class="btn-secondary"
                  >Complete</button>
                </article>
              </div>
              <div class="space-y-5">
                <.form
                  for={@task_form}
                  id="matter-task-form"
                  phx-submit="save-task"
                  class="activity-form"
                >
                  <h3 class="font-bold">Add task</h3>
                  <.input field={@task_form[:title]} label="Task" />
                  <.input field={@task_form[:description]} type="textarea" label="Notes" />
                  <.input
                    field={@task_form[:assignee_id]}
                    type="select"
                    label="Assignee"
                    options={Enum.map(@users, &{&1.name || &1.email, &1.id})}
                    prompt="Unassigned"
                  />
                  <.input field={@task_form[:due_on]} type="date" label="Due date" />
                  <.button id="save-matter-task" class="btn-primary">Add task</.button>
                </.form>
                <.form
                  :if={@workflows != []}
                  for={@workflow_form}
                  id="apply-workflow-form"
                  phx-submit="apply-workflow"
                  class="activity-form"
                >
                  <.input
                    field={@workflow_form[:id]}
                    type="select"
                    label="Workflow template"
                    options={Enum.map(@workflows, &{&1.name, &1.id})}
                  />
                  <.button id="apply-workflow" class="btn-secondary">Create checklist</.button>
                </.form>
              </div>
            </div>
          <% @tab == "calendar" -> %>
            <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
              <div id="matter-event-list" class="space-y-3">
                <p :if={@events == []} id="matter-events-empty" class="empty-copy">
                  No diary events yet.
                </p>
                <article :for={event <- @events} id={"matter-event-#{event.id}"} class="detail-card">
                  <span>{humanize(event.event_type)} · {Calendar.strftime(
                    event.starts_at,
                    "%d %b %Y, %H:%M"
                  )}</span><strong>{event.title}</strong>
                </article>
              </div>
              <.form
                for={@event_form}
                id="matter-event-form"
                phx-submit="save-event"
                class="activity-form"
              >
                <h3 class="font-bold">Add diary event</h3>
                <.input field={@event_form[:title]} label="Title" />
                <.input
                  field={@event_form[:event_type]}
                  type="select"
                  label="Type"
                  options={Enum.map(Sla.Practice.CalendarEvent.types(), &{humanize(&1), &1})}
                />
                <.input field={@event_form[:starts_at]} type="datetime-local" label="Starts" />
                <.input
                  field={@event_form[:assigned_to_id]}
                  type="select"
                  label="Assigned to"
                  options={Enum.map(@users, &{&1.name || &1.email, &1.id})}
                  prompt="Unassigned"
                />
                <.input field={@event_form[:court]} label="Court" />
                <.button id="save-matter-event" class="btn-primary">Add event</.button>
              </.form>
            </div>
          <% true -> %>
            <p class="empty-copy">The {@tab} workspace is ready for its delivery milestone.</p>
        <% end %>
      </section>
    </Layouts.app>
    """
  end

  defp humanize(value),
    do:
      value
      |> String.replace("_", " ")
      |> String.split()
      |> Enum.map_join(" ", &String.capitalize/1)

  defp refresh_billing(socket) do
    assign(socket,
      time_form: to_form(Billing.change_time_entry(%{date: Date.utc_today()}), as: :time_entry),
      disbursement_form:
        to_form(Billing.change_disbursement(%{date: Date.utc_today()}), as: :disbursement),
      financials: Billing.matter_summary(socket.assigns.matter.id),
      wip: Billing.list_unbilled(socket.assigns.matter.id)
    )
  end

  defp activity_form do
    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.to_naive()
      |> NaiveDateTime.to_iso8601()

    to_form(
      %{
        "action_type" => "note",
        "note" => "",
        "occurred_at" => now,
        "bring_up_in" => "",
        "custom_due_on" => "",
        "assignee_id" => "",
        "bring_up_note" => ""
      },
      as: :activity
    )
  end

  defp bring_up_attrs(%{"bring_up_in" => ""}, _user_id), do: nil

  defp bring_up_attrs(attrs, user_id) do
    due_on =
      if attrs["bring_up_in"] == "custom",
        do: attrs["custom_due_on"],
        else:
          Date.add(Date.utc_today(), String.to_integer(attrs["bring_up_in"])) |> Date.to_iso8601()

    %{
      "due_on" => due_on,
      "assignee_id" => blank_default(attrs["assignee_id"], user_id),
      "note" => blank_default(attrs["bring_up_note"], attrs["note"])
    }
  end

  defp blank_default(value, default) when value in [nil, ""], do: default
  defp blank_default(value, _default), do: value
end
