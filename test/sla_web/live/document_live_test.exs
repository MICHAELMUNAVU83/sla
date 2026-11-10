defmodule SlaWeb.DocumentLiveTest do
  use SlaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Sla.AccountsFixtures
  alias Sla.{Clients, Documents, Matters, Repo}

  setup %{conn: conn} do
    user = user_fixture(%{name: "Document Partner", role: "partner"})

    user =
      user
      |> Ecto.Changeset.change(
        totp_secret: NimbleTOTP.secret(),
        totp_enabled_at: DateTime.utc_now(:second)
      )
      |> Repo.update!()

    {:ok, client} = Clients.create_client(%{type: "individual", name: "Upload Client"})

    {:ok, matter} =
      Matters.create_matter(%{
        client_id: client.id,
        title: "Upload matter",
        practice_area: "real_estate",
        status: "open",
        opened_on: Date.utc_today(),
        responsible_advocate_id: user.id
      })

    %{
      conn: log_in_user(conn, user),
      user: user,
      client: client,
      matter: matter,
      category: hd(Documents.list_categories())
    }
  end

  test "uploads, lists, previews metadata, and adds a version", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/documents?matter_id=#{ctx.matter.id}")
    assert has_element?(view, "#document-drop-zone")

    upload =
      file_input(view, "#document-upload-form", :documents, [
        %{name: "title-search.txt", content: "registered title document", type: "text/plain"}
      ])

    assert render_upload(upload, "title-search.txt") =~ "100%"

    view
    |> form("#document-upload-form",
      document: %{
        client_id: ctx.client.id,
        matter_id: ctx.matter.id,
        category_id: ctx.category.id,
        title: "Title Search",
        tags: "land, search"
      }
    )
    |> render_submit()

    assert has_element?(view, "#documents .document-card")
    [document] = Documents.list_documents(ctx.user, %{matter_id: ctx.matter.id})
    {:ok, show, _html} = live(ctx.conn, ~p"/documents/#{document}")
    assert has_element?(show, "#download-document")

    version_upload =
      file_input(show, "#version-upload-form", :version, [
        %{name: "title-search-v2.txt", content: "updated title document", type: "text/plain"}
      ])

    render_upload(version_upload, "title-search-v2.txt")
    show |> form("#version-upload-form", version: %{}) |> render_submit()
    assert has_element?(show, "#version-history article", "Version 2")
  end

  test "matter and client tabs expose their document workspaces", ctx do
    {:ok, matter_view, _} = live(ctx.conn, ~p"/matters/#{ctx.matter}")
    matter_view |> element("#matter-tab-documents") |> render_click()
    assert has_element?(matter_view, "#matter-documents")
    {:ok, client_view, _} = live(ctx.conn, ~p"/clients/#{ctx.client}")
    client_view |> element("#client-tab-documents") |> render_click()
    assert has_element?(client_view, "#client-documents")
  end
end
