defmodule SlaWeb.MatterTabsTest do
  use SlaWeb.ConnCase
  import Phoenix.LiveViewTest
  import Sla.AccountsFixtures

  test "activity tab lists activities logged before the tab was opened", %{conn: conn} do
    user = user_fixture()
    client = Sla.Repo.insert!(%Sla.Clients.Client{name: "Tab Client", type: "company"})

    {:ok, matter} =
      Sla.Matters.create_matter(%Sla.Accounts.Scope{user: user}, %{
        "client_id" => client.id,
        "title" => "Tab matter",
        "practice_area" => "dispute_resolution",
        "opened_on" => Date.utc_today()
      })

    {:ok, _} =
      Sla.Tracker.create_activity(matter, user, %{
        "action_type" => "note",
        "note" => "Called the client",
        "occurred_at" =>
          NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second) |> NaiveDateTime.to_iso8601()
      })

    {:ok, view, _} = live(log_in_user(conn, user), ~p"/matters/#{matter}")
    view |> element("#matter-tab-activity") |> render_click()
    assert has_element?(view, "#activity-timeline .timeline-item", "Called the client")
  end
end
