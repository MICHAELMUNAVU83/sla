defmodule Sla.Tracker.Workers.DueReminder do
  use Oban.Worker, queue: :reminders, max_attempts: 3
  import Ecto.Query
  alias Sla.{Repo, Tracker}
  alias Sla.Tracker.BringUp

  @impl Oban.Worker
  def perform(_job) do
    today = Date.utc_today()

    BringUp
    |> where(
      [b],
      b.status in ["pending", "snoozed"] and b.due_on <= ^today and is_nil(b.notified_at)
    )
    |> preload([:matter, :assignee])
    |> Repo.all()
    |> Enum.each(fn bring_up ->
      {:ok, _} =
        Tracker.create_notification(%{
          user_id: bring_up.assignee_id,
          matter_id: bring_up.matter_id,
          bring_up_id: bring_up.id,
          type: "bring_up_due",
          title: "Bring-up due: #{bring_up.matter.file_number}",
          body: bring_up.note
        })

      bring_up |> Ecto.Changeset.change(notified_at: DateTime.utc_now(:second)) |> Repo.update!()
    end)

    :ok
  end
end
