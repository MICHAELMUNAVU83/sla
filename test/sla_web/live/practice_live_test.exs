defmodule SlaWeb.PracticeLiveTest do
  use SlaWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Sla.AccountsFixtures
  alias Sla.Repo

  setup %{conn: conn} do
    user = user_fixture(%{name: "Test Partner", role: "partner"})

    user =
      user
      |> Ecto.Changeset.change(
        totp_secret: NimbleTOTP.secret(),
        totp_enabled_at: DateTime.utc_now(:second)
      )
      |> Repo.update!()

    %{conn: log_in_user(conn, user), user: user}
  end

  test "submits intake and runs a stored conflict check", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/intake")
    assert has_element?(view, "#client-intake-form")

    view
    |> form("#client-intake-form",
      intake: %{
        client_type: "individual",
        name: "Amina Wanjiku",
        matter_summary: "New instructions",
        consent_given: true
      }
    )
    |> render_submit()

    assert has_element?(view, "#intake-queue article")

    view
    |> form("#conflict-check-form", conflict: %{search_terms: "Amina Wanjiku", notes: "Reviewed"})
    |> render_submit()

    assert has_element?(view, "#conflict-check-result")
  end

  test "renders the firm calendar and cause list", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/calendar")
    assert has_element?(view, "#court-cause-list")
    assert has_element?(view, "#firm-calendar-form")
  end
end
