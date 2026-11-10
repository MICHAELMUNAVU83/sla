defmodule SlaWeb.DiaryLiveTest do
  use SlaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Sla.AccountsFixtures
  alias Sla.{Clients, Matters, Repo, Tracker}

  setup %{conn: conn} do
    user = user_fixture(%{name: "Diary Partner", role: "partner"})

    user =
      user
      |> Ecto.Changeset.change(
        totp_secret: NimbleTOTP.secret(),
        totp_enabled_at: DateTime.utc_now(:second)
      )
      |> Repo.update!()

    {:ok, client} = Clients.create_client(%{type: "individual", name: "Diary Client"})

    {:ok, matter} =
      Matters.create_matter(%{
        client_id: client.id,
        title: "Diary matter",
        practice_area: "real_estate",
        status: "open",
        opened_on: Date.utc_today()
      })

    {:ok, {_activity, bring_up}} =
      Tracker.create_activity(
        matter,
        user,
        %{"action_type" => "call", "note" => "Called client"},
        %{"due_on" => Date.utc_today(), "assignee_id" => user.id, "note" => "Follow up today"}
      )

    %{conn: log_in_user(conn, user), bring_up: bring_up}
  end

  test "renders sections and completes a bring-up", %{conn: conn, bring_up: bring_up} do
    {:ok, view, _html} = live(conn, ~p"/diary")
    assert has_element?(view, "#diary-today article")
    view |> form("#complete-#{bring_up.id}", %{note: "Follow-up completed"}) |> render_submit()
    refute has_element?(view, "#diary-today article")
    assert Tracker.get_bring_up!(bring_up.id).status == "done"
  end
end
