# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Sla.Repo.insert!(%Sla.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Sla.Practice.{DeadlineRule, DocumentTemplate, WorkflowStep, WorkflowTemplate}
alias Sla.Repo
alias Sla.{Accounts, Billing, Clients, Tracker}
alias Sla.Accounts.User
alias Sla.Billing.Invoice
alias Sla.Practice.{CalendarEvent, MatterTask}
alias Sla.Tracker.{BringUp, FileActivity, Notification}

Repo.insert!(
  DeadlineRule.changeset(%DeadlineRule{}, %{
    name: "Enter appearance",
    trigger_event_type: "filing",
    days: 15,
    business_days: false,
    result_event_type: "deadline"
  }),
  on_conflict: :nothing
)

workflow =
  Repo.insert!(
    WorkflowTemplate.changeset(%WorkflowTemplate{}, %{
      name: "Conveyance – Purchase",
      practice_area: "real_estate",
      matter_type: "purchase",
      description: "Standard purchase conveyance checklist"
    }),
    on_conflict: :nothing,
    conflict_target: :name,
    returning: true
  )

if workflow.id do
  [
    {1, "Confirm instructions and KYC", 0},
    {2, "Conduct official search", 2},
    {3, "Review sale agreement", 5},
    {4, "Obtain Land Control Board consent", 21},
    {5, "Assess and pay stamp duty", 30},
    {6, "Lodge transfer for registration", 35}
  ]
  |> Enum.each(fn {position, title, days} ->
    Repo.insert!(
      WorkflowStep.changeset(%WorkflowStep{workflow_template_id: workflow.id}, %{
        title: title,
        days_from_start: days,
        position: position
      }),
      on_conflict: :nothing
    )
  end)
end

Repo.insert!(
  DocumentTemplate.changeset(%DocumentTemplate{}, %{
    name: "Matter status letter",
    format: "html",
    body:
      "<h1>RE: {{matter.title}}</h1><p>Dear {{client.name}},</p><p>We refer to matter {{matter.file_number}}.</p><p>Yours faithfully,<br>{{advocate.name}}</p>"
  }),
  on_conflict: :nothing
)

# Screenshot-ready development data. Lookups make this safe to run repeatedly.
demo_email = "staff.demo@sichangi.africa"

demo_user =
  Accounts.get_user_by_email(demo_email) ||
    case Accounts.register_user(%{email: demo_email}) do
      {:ok, user} -> user
      {:error, changeset} -> raise "Could not seed demo user: #{inspect(changeset.errors)}"
    end

demo_user =
  if demo_user.hashed_password do
    demo_user
  else
    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(demo_user, %{password: "SlaDemo!2026"})

    user
  end

demo_user =
  if demo_user.confirmed_at,
    do: demo_user,
    else: demo_user |> User.confirm_changeset() |> Repo.update!()

{:ok, demo_user} =
  Accounts.update_user_admin(demo_user, %{
    name: "SLA Demo User",
    role: "admin",
    active: true
  })

client_specs = [
  %{
    type: "company",
    name: "Kijani Infrastructure PLC",
    kra_pin: "P051234567K",
    email: "legal@kijani.example",
    phone: "+254 709 420 100",
    address: "Riverside Drive, Nairobi",
    kyc_status: "verified"
  },
  %{
    type: "company",
    name: "Acacia Capital Partners",
    kra_pin: "P051234568L",
    email: "operations@acaciacapital.example",
    phone: "+254 720 118 400",
    address: "Waiyaki Way, Nairobi",
    kyc_status: "in_review"
  },
  %{
    type: "individual",
    name: "Njeri Kamau",
    identification_number: "28400117",
    email: "njeri.kamau@example.com",
    phone: "+254 722 305 880",
    address: "Karen, Nairobi",
    kyc_status: "verified"
  }
]

clients =
  Map.new(client_specs, fn attrs ->
    client =
      Repo.get_by(Sla.Clients.Client, name: attrs.name) ||
        case Clients.create_client(attrs) do
          {:ok, client} -> client
          {:error, changeset} -> raise "Could not seed client: #{inspect(changeset.errors)}"
        end

    {attrs.name, client}
  end)

today = Date.utc_today()

matter_specs = [
  %{
    file_number: "SLA/CC/2026/041",
    client: "Kijani Infrastructure PLC",
    title: "Regional infrastructure joint venture",
    practice_area: "corporate_commercial",
    opened_on: Date.add(today, -82),
    summary: "Joint venture agreement revised and circulated to the client."
  },
  %{
    file_number: "SLA/DR/2026/027",
    client: "Acacia Capital Partners",
    title: "Acacia Capital v Meridian Holdings",
    practice_area: "dispute_resolution",
    opened_on: Date.add(today, -46),
    court: "High Court of Kenya — Commercial Division",
    case_number: "HCCOMM E184 of 2026",
    summary: "Hearing bundle filed; awaiting confirmation from opposing counsel."
  },
  %{
    file_number: "SLA/RE/2026/063",
    client: "Njeri Kamau",
    title: "Karen residential conveyance",
    practice_area: "real_estate",
    opened_on: Date.add(today, -25),
    summary: "Completion documents received for final review."
  },
  %{
    file_number: "SLA/BF/2026/018",
    client: "Kijani Infrastructure PLC",
    title: "KES 850M syndicated facility",
    practice_area: "banking_finance",
    opened_on: Date.add(today, -18),
    summary: "Conditions precedent tracker updated after lender call."
  }
]

matters =
  Map.new(matter_specs, fn spec ->
    client = Map.fetch!(clients, spec.client)

    matter =
      Repo.get_by(Sla.Matters.Matter, file_number: spec.file_number) ||
        %Sla.Matters.Matter{file_number: spec.file_number}
        |> Sla.Matters.Matter.changeset(%{
          client_id: client.id,
          title: spec.title,
          practice_area: spec.practice_area,
          status: "open",
          opened_on: spec.opened_on,
          responsible_advocate_id: demo_user.id,
          court: Map.get(spec, :court),
          case_number: Map.get(spec, :case_number)
        })
        |> Repo.insert!()

    unless Repo.get_by(FileActivity, matter_id: matter.id, note: spec.summary) do
      {:ok, {_activity, _bring_up}} =
        Tracker.create_activity(matter, demo_user, %{
          action_type: "note",
          note: spec.summary,
          occurred_at: DateTime.utc_now(:second)
        })
    end

    {spec.file_number, Repo.get!(Sla.Matters.Matter, matter.id)}
  end)

dispute = Map.fetch!(matters, "SLA/DR/2026/027")
property = Map.fetch!(matters, "SLA/RE/2026/063")
finance = Map.fetch!(matters, "SLA/BF/2026/018")

[
  {dispute, "Prepare authorities bundle", Date.add(today, -1), "in_progress"},
  {dispute, "Confirm witness availability", today, "pending"},
  {property, "Review completion documents", Date.add(today, 2), "pending"},
  {finance, "Clear remaining conditions precedent", Date.add(today, 5), "pending"}
]
|> Enum.each(fn {matter, title, due_on, status} ->
  Repo.get_by(MatterTask, matter_id: matter.id, title: title) ||
    %MatterTask{matter_id: matter.id, created_by_id: demo_user.id}
    |> MatterTask.changeset(%{
      assignee_id: demo_user.id,
      title: title,
      due_on: due_on,
      status: status
    })
    |> Repo.insert!()
end)

[
  {dispute, "Directions hearing — Acacia v Meridian", "hearing", today, ~T[09:00:00],
   "Milimani Commercial Courts"},
  {property, "Client completion meeting", "meeting", Date.add(today, 1), ~T[11:30:00],
   "SLA Boardroom"},
  {finance, "Facility documents execution", "deadline", Date.add(today, 4), ~T[16:00:00],
   "Online"}
]
|> Enum.each(fn {matter, title, type, date, time, location} ->
  Repo.get_by(CalendarEvent, title: title) ||
    %CalendarEvent{created_by_id: demo_user.id}
    |> CalendarEvent.changeset(%{
      matter_id: matter.id,
      assigned_to_id: demo_user.id,
      title: title,
      event_type: type,
      starts_at: DateTime.new!(date, time, "Etc/UTC"),
      location: location,
      court: if(type == "hearing", do: location)
    })
    |> Repo.insert!()
end)

[
  {dispute, "Follow up on the sealed hearing notice", Date.add(today, -1)},
  {property, "Call client with completion update", today},
  {finance, "Send updated CP tracker to lender counsel", Date.add(today, 3)}
]
|> Enum.each(fn {matter, note, due_on} ->
  Repo.get_by(BringUp, matter_id: matter.id, note: note) ||
    %BringUp{}
    |> BringUp.changeset(%{
      matter_id: matter.id,
      assignee_id: demo_user.id,
      created_by_id: demo_user.id,
      due_on: due_on,
      note: note,
      status: "pending"
    })
    |> Repo.insert!()
end)

unless Repo.get_by(Sla.Billing.TimeEntry,
         matter_id: dispute.id,
         description: "Prepare hearing strategy and authorities"
       ) do
  {:ok, _entry} =
    Billing.create_time_entry(dispute, demo_user, %{
      date: today,
      minutes: 195,
      rate: Decimal.new("18500"),
      description: "Prepare hearing strategy and authorities",
      billable: true
    })
end

unless Repo.get_by(Invoice, number: "INV-DEMO-2026-041") do
  %Invoice{number: "INV-DEMO-2026-041", client_id: dispute.client_id, matter_id: dispute.id}
  |> Invoice.changeset(%{
    type: "tax",
    status: "issued",
    currency: "KES",
    issued_on: Date.add(today, -18),
    due_on: Date.add(today, 12),
    subtotal: Decimal.new("320000"),
    vat: Decimal.new("51200"),
    total: Decimal.new("371200")
  })
  |> Repo.insert!()
end

unless Repo.get_by(Notification, user_id: demo_user.id, title: "Hearing today") do
  {:ok, _notification} =
    Tracker.create_notification(%{
      user_id: demo_user.id,
      matter_id: dispute.id,
      type: "deadline",
      title: "Hearing today",
      body: "Directions hearing for #{dispute.file_number} is scheduled for 09:00."
    })
end

IO.puts("Seeded screenshot data for #{demo_email}")
