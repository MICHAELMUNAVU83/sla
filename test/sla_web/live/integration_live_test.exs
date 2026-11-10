defmodule SlaWeb.IntegrationLiveTest do
  use SlaWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Sla.AccountsFixtures
  alias Sla.Repo

  setup %{conn: conn} do
    user = user_fixture(%{name: "Integration Partner", role: "partner"})

    user =
      user
      |> Ecto.Changeset.change(
        totp_secret: NimbleTOTP.secret(),
        totp_enabled_at: DateTime.utc_now(:second)
      )
      |> Repo.update!()

    %{conn: log_in_user(conn, user)}
  end

  test "renders and enables integration catalog", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/integrations")
    assert has_element?(view, "#integration-catalog")
    assert has_element?(view, "#integration-mpesa")
    view |> element("#enable-mpesa") |> render_click()
    assert has_element?(view, "#integration-mpesa")
  end
end
