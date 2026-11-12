defmodule SlaWeb.ManualLiveTest do
  use SlaWeb.ConnCase
  import Phoenix.LiveViewTest
  import Sla.AccountsFixtures

  test "renders every manual section and its screenshots exist", %{conn: conn} do
    {:ok, view, _html} = live(log_in_user(conn, user_fixture()), ~p"/manual")
    assert has_element?(view, "#manual-contents")

    for id <- ~w(clients cases bring-ups calendar documents fees allocation) do
      assert has_element?(view, "##{id}")
    end

    for img <-
          view
          |> render()
          |> LazyHTML.from_fragment()
          |> LazyHTML.query(".manual-shot img")
          |> LazyHTML.attribute("src") do
      assert File.exists?(Path.join("priv/static", img)), "missing manual screenshot #{img}"
    end
  end
end
