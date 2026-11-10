defmodule SlaWeb.PortalSessionController do
  use SlaWeb, :controller
  alias Sla.Integrations

  def create(conn, %{"portal" => %{"email" => email, "password" => password}}) do
    case Integrations.authenticate_portal(email, password) do
      {:ok, account} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:portal_account_id, account.id)
        |> redirect(to: ~p"/portal")

      {:error, _} ->
        conn |> put_flash(:error, "Invalid email or password") |> redirect(to: ~p"/portal/log-in")
    end
  end

  def delete(conn, _params),
    do: conn |> delete_session(:portal_account_id) |> redirect(to: ~p"/portal/log-in")
end
