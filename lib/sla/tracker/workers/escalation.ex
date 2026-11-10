defmodule Sla.Tracker.Workers.Escalation do
  use Oban.Worker, queue: :reminders, max_attempts: 3
  import Ecto.Query
  alias Sla.{Repo, Tracker}
  alias Sla.Accounts.User
  alias Sla.Tracker.BringUp

  @impl Oban.Worker
  def perform(_job) do
    days = Application.get_env(:sla, :tracker, []) |> Keyword.get(:escalation_days, 3)
    cutoff = Date.add(Date.utc_today(), -days)
    partners = Repo.all(from u in User, where: u.active and u.role == "partner")

    BringUp
    |> where(
      [b],
      b.status in ["pending", "snoozed"] and b.due_on <= ^cutoff and is_nil(b.escalated_at)
    )
    |> preload([:matter, :assignee])
    |> Repo.all()
    |> Enum.each(fn bring_up ->
      Enum.each(partners, fn partner ->
        {:ok, _} =
          Tracker.create_notification(%{
            user_id: partner.id,
            matter_id: bring_up.matter_id,
            bring_up_id: bring_up.id,
            type: "bring_up_escalated",
            title: "Overdue bring-up escalation",
            body:
              "#{bring_up.matter.file_number} is overdue for #{bring_up.assignee.name || bring_up.assignee.email}: #{bring_up.note}"
          })
      end)

      bring_up |> Ecto.Changeset.change(escalated_at: DateTime.utc_now(:second)) |> Repo.update!()
    end)

    :ok
  end
end
