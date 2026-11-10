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
