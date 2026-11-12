defmodule SlaWeb.AllocationLiveTest do
  use SlaWeb.ConnCase
  import Phoenix.LiveViewTest
  import Sla.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "shows each team member's workload", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/allocation")
    assert has_element?(view, "#team-workload")
    assert has_element?(view, "#member-#{user.id}")
    assert has_element?(view, "#reassign-form")
  end
end
