defmodule SlaWeb.PageControllerTest do
  use SlaWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    document = conn |> html_response(200) |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#Main") |> LazyHTML.to_html() != ""

    assert document
           |> LazyHTML.query("#staff-login-button[href='/users/log-in']")
           |> LazyHTML.to_html() != ""

    assert document
           |> LazyHTML.query("#services")
           |> LazyHTML.to_html() != ""
  end
end
