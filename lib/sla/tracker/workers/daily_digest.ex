defmodule Sla.Tracker.Workers.DailyDigest do
  use Oban.Worker, queue: :mailers, max_attempts: 3
  import Ecto.Query
  alias Sla.{Mailer, Repo}
  alias Sla.Tracker.BringUp
  alias Swoosh.Email

  @impl Oban.Worker
  def perform(_job) do
    today = Date.utc_today()

    BringUp
    |> where([b], b.status in ["pending", "snoozed"] and b.due_on <= ^today)
    |> preload([:matter, :assignee])
    |> Repo.all()
    |> Enum.group_by(& &1.assignee)
    |> Enum.each(fn {user, items} ->
      if get_in(user.notification_preferences, ["email"]) != false do
        lines =
          Enum.map_join(items, "\n", &"• #{&1.matter.file_number} — #{&1.note} (#{&1.due_on})")

        Email.new()
        |> Email.to(user.email)
        |> Email.from({"SLA Practice ERP", "notifications@sla.local"})
        |> Email.subject("SLA daily diary — #{length(items)} item(s) due")
        |> Email.text_body("Your due and overdue bring-ups:\n\n#{lines}")
        |> Mailer.deliver()
      end
    end)

    :ok
  end
end
