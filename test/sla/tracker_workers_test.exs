defmodule Sla.TrackerWorkersTest do
  use Sla.DataCase, async: false
  use Oban.Testing, repo: Sla.Repo
  import Sla.AccountsFixtures
  import Swoosh.TestAssertions
  alias Sla.{Clients, Matters, Repo, Tracker}
  alias Sla.Tracker.Workers.{DailyDigest, DormantMatter, DueReminder, Escalation}

  setup do
    partner = user_fixture(%{name: "Responsible Partner", role: "partner"})
    user = user_fixture(%{name: "Associate", role: "associate"})
    {:ok, client} = Clients.create_client(%{type: "company", name: "Worker Client"})

    {:ok, matter} =
      Matters.create_matter(%{
        client_id: client.id,
        title: "Worker matter",
        practice_area: "corporate_commercial",
        status: "open",
        opened_on: Date.add(Date.utc_today(), -100),
        responsible_advocate_id: partner.id
      })

    assert_email_sent()
    assert_email_sent()
    %{partner: partner, user: user, matter: matter}
  end

  test "due reminder and daily digest create notification and email", %{
    user: user,
    matter: matter
  } do
    {:ok, {_activity, _}} =
      Tracker.create_activity(matter, user, %{"action_type" => "note", "note" => "Due work"}, %{
        "due_on" => Date.utc_today(),
        "assignee_id" => user.id,
        "note" => "Attend deadline"
      })

    assert :ok = perform_job(DueReminder, %{})
    assert Tracker.unread_count(user.id) == 1
    assert :ok = perform_job(DailyDigest, %{})
    assert_email_sent(subject: "SLA daily diary — 1 item(s) due", to: user.email)
  end

  test "escalation notifies partners and dormant worker flags stale matters", %{
    partner: partner,
    user: user,
    matter: matter
  } do
    {:ok, {_activity, bring_up}} =
      Tracker.create_activity(matter, user, %{"action_type" => "note", "note" => "Old task"}, %{
        "due_on" => Date.add(Date.utc_today(), -5),
        "assignee_id" => user.id,
        "note" => "Overdue"
      })

    assert :ok = perform_job(Escalation, %{})
    assert Repo.reload!(bring_up).escalated_at
    assert Tracker.unread_count(partner.id) == 1

    matter
    |> Ecto.Changeset.change(
      last_activity_at: DateTime.add(DateTime.utc_now(:second), -100, :day)
    )
    |> Repo.update!()

    assert :ok = perform_job(DormantMatter, %{})
    assert Repo.reload!(matter).dormant_alerted_at
    assert Tracker.unread_count(partner.id) >= 2
  end
end
