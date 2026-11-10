defmodule Sla.Tracker do
  @moduledoc "Append-only file activity, bring-ups, and in-app notifications."
  import Ecto.Query, warn: false
  alias Sla.Repo
  alias Sla.Tracker.{BringUp, FileActivity, Notification}

  @topic "tracker"
  def subscribe, do: Phoenix.PubSub.subscribe(Sla.PubSub, @topic)

  def list_activities(matter_id) do
    FileActivity
    |> where([a], a.matter_id == ^matter_id)
    |> order_by([a], desc: a.occurred_at, desc: a.id)
    |> preload(:user)
    |> Repo.all()
  end

  def create_activity(matter, user, attrs, bring_up_attrs \\ nil) do
    Repo.transact(fn ->
      occurred_at = parse_datetime(Map.get(attrs, "occurred_at") || Map.get(attrs, :occurred_at))

      activity_attrs = %{
        matter_id: matter.id,
        user_id: user.id,
        action_type: value(attrs, :action_type),
        note: value(attrs, :note),
        occurred_at: occurred_at,
        document_id: value(attrs, :document_id),
        email_ref: value(attrs, :email_ref)
      }

      with {:ok, activity} <-
             %FileActivity{} |> FileActivity.changeset(activity_attrs) |> Repo.insert(),
           {:ok, _matter} <- update_latest_action(matter, activity),
           {:ok, bring_up} <- maybe_create_bring_up(activity, user, bring_up_attrs) do
        activity = Repo.preload(activity, :user)
        broadcast({:activity_created, activity})

        if bring_up,
          do: broadcast({:bring_up_changed, Repo.preload(bring_up, [:matter, :assignee])})

        {:ok, {activity, bring_up}}
      end
    end)
  end

  def get_bring_up!(id),
    do: BringUp |> Repo.get!(id) |> Repo.preload([:matter, :assignee, :created_by])

  def diary(user_id, params \\ %{}) do
    assignee_id = Map.get(params, "assignee", user_id)
    today = Date.utc_today()

    items =
      BringUp
      |> where([b], b.assignee_id == ^assignee_id and b.status in ["pending", "snoozed"])
      |> order_by([b], asc: b.due_on, asc: b.id)
      |> preload([:matter, :assignee, :created_by])
      |> Repo.all()

    %{
      overdue: Enum.filter(items, &Date.before?(&1.due_on, today)),
      today: Enum.filter(items, &(&1.due_on == today)),
      upcoming: Enum.filter(items, &Date.after?(&1.due_on, today))
    }
  end

  def complete_bring_up(bring_up, user, note) do
    Repo.transact(fn ->
      with {:ok, {activity, _}} <-
             create_activity(bring_up.matter, user, %{"action_type" => "note", "note" => note}),
           {:ok, updated} <-
             bring_up
             |> BringUp.changeset(%{status: "done", completed_at: DateTime.utc_now(:second)})
             |> Repo.update() do
        broadcast({:bring_up_changed, Repo.preload(updated, [:matter, :assignee])})
        {:ok, {updated, activity}}
      end
    end)
  end

  def snooze_bring_up(bring_up, due_on),
    do: update_bring_up(bring_up, %{status: "snoozed", due_on: due_on, notified_at: nil})

  def reassign_bring_up(bring_up, assignee_id),
    do: update_bring_up(bring_up, %{assignee_id: assignee_id})

  def cancel_bring_up(bring_up), do: update_bring_up(bring_up, %{status: "cancelled"})

  def create_bring_up(attrs) do
    %BringUp{}
    |> BringUp.changeset(attrs)
    |> Repo.insert()
  end

  def create_notification(attrs),
    do: %Notification{} |> Notification.changeset(attrs) |> Repo.insert()

  def unread_notifications(user_id),
    do:
      Notification
      |> where([n], n.user_id == ^user_id and is_nil(n.read_at))
      |> order_by([n], desc: n.inserted_at)
      |> limit(20)
      |> Repo.all()

  def unread_count(user_id),
    do:
      Repo.aggregate(
        from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at)),
        :count
      )

  def mark_notifications_read(user_id),
    do:
      Repo.update_all(from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at)),
        set: [read_at: DateTime.utc_now(:second)]
      )

  def update_notification_preferences(user, attrs),
    do:
      user
      |> Sla.Accounts.User.notification_changeset(%{notification_preferences: attrs})
      |> Repo.update()

  defp maybe_create_bring_up(_activity, _user, nil), do: {:ok, nil}
  defp maybe_create_bring_up(_activity, _user, %{"due_on" => ""}), do: {:ok, nil}

  defp maybe_create_bring_up(activity, user, attrs) do
    attrs = %{
      matter_id: activity.matter_id,
      activity_id: activity.id,
      created_by_id: user.id,
      assignee_id: value(attrs, :assignee_id) || user.id,
      due_on: value(attrs, :due_on),
      note: value(attrs, :note) || activity.note,
      status: value(attrs, :status) || "pending"
    }

    %BringUp{} |> BringUp.changeset(attrs) |> Repo.insert()
  end

  defp update_latest_action(matter, activity),
    do:
      matter
      |> Ecto.Changeset.change(
        last_activity_at: activity.occurred_at,
        last_activity_summary: String.slice(activity.note, 0, 240),
        dormant_alerted_at: nil
      )
      |> Repo.update()

  defp update_bring_up(bring_up, attrs) do
    case bring_up |> BringUp.changeset(attrs) |> Repo.update() do
      {:ok, updated} ->
        broadcast({:bring_up_changed, Repo.preload(updated, [:matter, :assignee])})
        {:ok, updated}

      error ->
        error
    end
  end

  defp parse_datetime(%DateTime{} = dt), do: DateTime.truncate(dt, :second)
  defp parse_datetime(nil), do: DateTime.utc_now(:second)

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} ->
        DateTime.truncate(dt, :second)

      _ ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, naive} -> DateTime.from_naive!(naive, "Etc/UTC") |> DateTime.truncate(:second)
          _ -> DateTime.utc_now(:second)
        end
    end
  end

  defp broadcast(message), do: Phoenix.PubSub.broadcast(Sla.PubSub, @topic, message)
  defp value(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
end
