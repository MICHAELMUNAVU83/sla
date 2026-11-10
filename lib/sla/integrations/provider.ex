defmodule Sla.Integrations.Provider do
  @moduledoc "HTTP boundary for vendor integrations. Uses Req and injectable adapters in tests."

  def request(provider, method, path, options \\ []) do
    config = Application.get_env(:sla, :integrations, []) |> Keyword.get(provider, [])

    with base_url when is_binary(base_url) <- config[:base_url],
         token when is_binary(token) <- config[:token] do
      Req.request(
        Keyword.merge(options,
          method: method,
          url: base_url <> path,
          auth: {:bearer, token},
          retry: :transient,
          max_retries: 3,
          receive_timeout: 15_000
        )
      )
      |> normalize()
    else
      _ -> {:error, :not_configured}
    end
  end

  defp normalize({:ok, %{status: status, body: body}}) when status in 200..299, do: {:ok, body}
  defp normalize({:ok, response}), do: {:error, {:http_error, response.status, response.body}}
  defp normalize({:error, reason}), do: {:error, reason}
end
