defmodule SlaWeb.DocumentFileController do
  use SlaWeb, :controller
  alias Sla.{Documents, Storage}

  def download(conn, %{"id" => id}), do: serve(conn, id, "attachment")
  def preview(conn, %{"id" => id}), do: serve(conn, id, "inline")

  defp serve(conn, id, disposition) do
    user = conn.assigns.current_scope.user

    if !Sla.Accounts.totp_enabled?(user) do
      conn
      |> put_flash(:error, "Set up two-factor authentication to continue.")
      |> redirect(to: ~p"/users/two-factor/setup")
      |> halt()
    else
      serve_document(conn, user, id, disposition)
    end
  end

  defp serve_document(conn, user, id, disposition) do
    document = Documents.get_document!(user, id)
    version = document.current_version
    filename = version.filename |> Path.basename() |> String.replace(~r/[\r\n"]/, "")

    conn =
      conn
      |> put_resp_content_type(version.content_type)
      |> put_resp_header("content-disposition", ~s(#{disposition}; filename="#{filename}"))

    case Storage.read(version.storage_key) do
      {:ok, body} ->
        send_resp(conn, 200, body)

      {:error, :remote_storage} ->
        {:ok, url} = Storage.url(version.storage_key)
        redirect(conn, external: url)

      {:error, :enoent} ->
        send_resp(conn, 404, "File not found")
    end
  end
end
