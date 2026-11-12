defmodule Sla.Allocation do
  @moduledoc "Work allocation: who is handling which matters, tasks, bring-ups and diary events."
  import Ecto.Query, warn: false
  alias Sla.{Accounts, Matters, Repo}
  alias Sla.Practice.{CalendarEvent, MatterTask}
  alias Sla.Tracker.BringUp

  @doc "Returns one workload entry per team member, plus the unassigned matters, for matters visible to `user`."
  def workload(user) do
    matters = user |> Matters.list_matters_for_user() |> Enum.reject(&(&1.status == "closed"))
    matter_ids = Enum.map(matters, & &1.id)
    today = Date.utc_today()

    tasks =
      Repo.all(
        from t in MatterTask,
          where: t.matter_id in ^matter_ids and t.status != "completed",
          order_by: [asc_nulls_last: t.due_on],
          preload: [:matter]
      )

    bring_ups =
      Repo.all(
        from b in BringUp,
          where: b.matter_id in ^matter_ids and b.status == "pending",
          order_by: b.due_on,
          preload: [:matter]
      )

    events =
      Repo.all(
        from e in CalendarEvent,
          where: e.starts_at >= ^DateTime.utc_now() and not is_nil(e.assigned_to_id),
          order_by: e.starts_at,
          preload: [:matter]
      )

    members =
      Enum.map(Accounts.list_users(), fn member ->
        my_tasks = Enum.filter(tasks, &(&1.assignee_id == member.id))
        my_bring_ups = Enum.filter(bring_ups, &(&1.assignee_id == member.id))

        %{
          user: member,
          matters: Enum.filter(matters, &(&1.responsible_advocate_id == member.id)),
          tasks: my_tasks,
          bring_ups: my_bring_ups,
          events: Enum.filter(events, &(&1.assigned_to_id == member.id)),
          overdue:
            Enum.count(my_tasks, &(&1.due_on && Date.before?(&1.due_on, today))) +
              Enum.count(my_bring_ups, &Date.before?(&1.due_on, today))
        }
      end)

    %{
      members: members,
      matters: matters,
      unassigned: Enum.filter(matters, &is_nil(&1.responsible_advocate_id))
    }
  end

  @doc "Moves a matter to a new responsible advocate."
  def reassign_matter(user, matter_id, advocate_id) do
    matter = Matters.get_matter_for_user!(matter_id, user)
    Matters.update_matter(matter, %{responsible_advocate_id: blank_to_nil(advocate_id)})
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
