defmodule Sla.TrackerTest do
  use Sla.DataCase, async: true
  import Sla.AccountsFixtures
  alias Sla.{Clients, Matters, Tracker}

  setup do
    user = user_fixture(%{name: "Diary User", role: "associate"})
    {:ok, client} = Clients.create_client(%{type: "individual", name: "Tracker Client"})

    {:ok, matter} =
      Matters.create_matter(%{
        client_id: client.id,
        title: "Tracked matter",
        practice_area: "dispute_resolution",
        status: "open",
        opened_on: Date.utc_today()
      })

    %{user: user, matter: matter}
  end

  test "activity updates latest action and creates an assigned bring-up", %{
    user: user,
    matter: matter
  } do
    assert {:ok, {activity, bring_up}} =
             Tracker.create_activity(
               matter,
               user,
               %{"action_type" => "call", "note" => "Called client with filing update"},
               %{
                 "due_on" => Date.add(Date.utc_today(), 3),
                 "assignee_id" => user.id,
                 "note" => "Check filing response"
               }
             )

    assert activity.action_type == "call"
    assert bring_up.activity_id == activity.id

    assert Matters.get_matter!(matter.id).last_activity_summary ==
             "Called client with filing update"

    assert [listed] = Tracker.list_activities(matter.id)
    assert listed.id == activity.id
  end

  test "bring-up supports snooze, reassign, cancel and completion with correction activity", %{
    user: user,
    matter: matter
  } do
    other = user_fixture(%{name: "Other User"})

    {:ok, {_activity, bring_up}} =
      Tracker.create_activity(
        matter,
        user,
        %{"action_type" => "filing", "note" => "Filed defence"},
        %{"due_on" => Date.utc_today(), "assignee_id" => user.id, "note" => "Confirm service"}
      )

    assert {:ok, snoozed} = Tracker.snooze_bring_up(bring_up, Date.add(Date.utc_today(), 7))
    assert snoozed.status == "snoozed"
    assert {:ok, reassigned} = Tracker.reassign_bring_up(snoozed, other.id)
    assert reassigned.assignee_id == other.id

    assert {:ok, {_done, completion}} =
             Tracker.complete_bring_up(
               Tracker.get_bring_up!(reassigned.id),
               user,
               "Service confirmed"
             )

    assert completion.note == "Service confirmed"

    {:ok, {_activity, cancellable}} =
      Tracker.create_activity(
        matter,
        user,
        %{"action_type" => "note", "note" => "New follow-up"},
        %{"due_on" => Date.utc_today(), "assignee_id" => user.id, "note" => "Cancel me"}
      )

    assert {:ok, %{status: "cancelled"}} = Tracker.cancel_bring_up(cancellable)
  end
end
