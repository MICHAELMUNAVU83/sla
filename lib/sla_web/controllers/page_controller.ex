defmodule SlaWeb.PageController do
  use SlaWeb, :controller

  def home(conn, _params) do
    html =
      :sla
      |> Application.app_dir("priv/static/index.html")
      |> File.read!()
      |> String.replace("</body>", session_context(conn) <> "</body>")

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  defp session_context(%{assigns: %{current_scope: %{user: user}}}) when not is_nil(user) do
    email = user.email |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()

    ~s(<div class="sr-only"><span>#{email}</span><a href="/users/settings">Settings</a><a href="/users/log-out">Log out</a></div>)
  end

  defp session_context(_conn), do: ""
end
