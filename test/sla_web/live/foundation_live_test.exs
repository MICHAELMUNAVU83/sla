defmodule SlaWeb.FoundationLiveTest do
  use SlaWeb.ConnCase, async: true
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

  test "client CRUD flow", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/clients/new")
    assert has_element?(view, "#client-form")

    view
    |> form("#client-form",
      client: %{
        type: "company",
        name: "Karibu Holdings",
        email: "legal@karibu.test",
        kyc_status: "pending"
      }
    )
    |> render_submit()

    {path, _flash} = assert_redirect(view)
    assert path =~ "/clients/"
    {:ok, show, _html} = live(conn, path)
    assert has_element?(show, "#edit-client")
  end

  test "matter CRUD flow", %{conn: conn} do
    {:ok, client} = Sla.Clients.create_client(%{type: "individual", name: "Musa Otieno"})
    {:ok, view, _html} = live(conn, ~p"/matters/new")
    assert has_element?(view, "#matter-form")

    view
    |> form("#matter-form",
      matter: %{
        client_id: client.id,
        title: "Commercial dispute",
        practice_area: "dispute_resolution",
        status: "open",
        opened_on: "2026-11-10"
      }
    )
    |> render_submit()

    {path, _flash} = assert_redirect(view)
    assert path =~ "/matters/"
    {:ok, show, _html} = live(conn, path)
    assert has_element?(show, "#matter-tabs")
  end
end
