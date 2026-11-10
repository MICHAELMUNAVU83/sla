defmodule SlaWeb.IntegrationWebhookController do
  use SlaWeb, :controller
  alias Sla.Integrations

  def receive(conn, %{"provider" => provider} = payload) do
    with :ok <- authenticate(conn, provider),
         external_id when is_binary(external_id) <- external_id(payload),
         {:ok, _event} <-
           normalize(
             Integrations.receive(provider, external_id, payload["kind"] || "callback", payload)
           ) do
      json(conn, %{status: "accepted"})
    else
      {:error, :unauthorized} ->
        conn |> put_status(:unauthorized) |> json(%{error: "unauthorized"})

      _ ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "invalid callback"})
    end
  end

  defp authenticate(conn, provider) do
    expected =
      Application.get_env(:sla, :integrations, [])
      |> Keyword.get(String.to_existing_atom(provider), [])
      |> Keyword.get(:webhook_token)

    presented = get_req_header(conn, "x-webhook-token") |> List.first()

    if is_binary(expected) and is_binary(presented) and
         byte_size(expected) == byte_size(presented) and
         Plug.Crypto.secure_compare(expected, presented), do: :ok, else: {:error, :unauthorized}
  rescue
    ArgumentError -> {:error, :unauthorized}
  end

  defp external_id(payload),
    do: payload["external_id"] || payload["transaction_id"] || payload["id"]

  defp normalize({:ok, event, :duplicate}), do: {:ok, event}
  defp normalize(result), do: result
end
