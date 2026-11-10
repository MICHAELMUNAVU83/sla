defmodule Sla.Tracker.Workers.DormantMatter do
  use Oban.Worker, queue: :reminders, max_attempts: 3
  import Ecto.Query
  alias Sla.{Repo, Tracker}
  alias Sla.Accounts.User
  alias Sla.Matters.Matter

  @impl Oban.Worker
  def perform(_job) do
    thresholds =
      Application.get_env(:sla, :tracker, []) |> Keyword.get(:dormant_days, [30, 60, 90])

    today = Date.utc_today()
    partners = Repo.all(from u in User, where: u.active and u.role == "partner")

    Matter
    |> where([m], m.status == "open")
    |> Repo.all()
    |> Enum.each(fn matter ->
      last_date =
        if matter.last_activity_at,
          do: DateTime.to_date(matter.last_activity_at),
          else: matter.opened_on

      inactive_days = Date.diff(today, last_date)
      threshold = thresholds |> Enum.filter(&(&1 <= inactive_days)) |> Enum.max(fn -> nil end)

      last_alert_old? =
        is_nil(matter.dormant_alerted_at) or
          Date.diff(today, DateTime.to_date(matter.dormant_alerted_at)) >= 30

      if threshold && last_alert_old? do
        recipients =
          partners ++
            Enum.filter(
              [matter.responsible_advocate_id && Repo.get(User, matter.responsible_advocate_id)],
              & &1
            )

        recipients
        |> Enum.uniq_by(& &1.id)
        |> Enum.each(fn user ->
          {:ok, _} =
            Tracker.create_notification(%{
              user_id: user.id,
              matter_id: matter.id,
              type: "matter_dormant",
              title: "Dormant matter: #{matter.file_number}",
              body: "No file activity for #{inactive_days} days."
            })
        end)

        matter
        |> Ecto.Changeset.change(dormant_alerted_at: DateTime.utc_now(:second))
        |> Repo.update!()
      end
    end)

    :ok
  end
end
