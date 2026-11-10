defmodule Sla.AI.Claude do
  @behaviour Sla.AI.Provider
  @endpoint "https://api.anthropic.com/v1/messages"

  @impl true
  def generate(prompt, opts) do
    config = Application.get_env(:sla, Sla.AI, [])
    api_key = Keyword.get(config, :api_key) || System.get_env("ANTHROPIC_API_KEY")

    if api_key in [nil, ""],
      do: {:error, :missing_api_key},
      else: request(api_key, prompt, opts, config)
  end

  defp request(api_key, prompt, opts, config) do
    body = %{
      model: Keyword.fetch!(opts, :model),
      max_tokens: Keyword.get(opts, :max_tokens, 1_500),
      system:
        "You are a careful Kenyan legal practice assistant. Return only valid JSON. Never invent facts.",
      messages: [%{role: "user", content: prompt}]
    }

    case Req.post(@endpoint,
           json: body,
           headers: [{"x-api-key", api_key}, {"anthropic-version", "2023-06-01"}],
           retry: :transient,
           max_retries: Keyword.get(config, :retries, 2),
           receive_timeout: Keyword.get(config, :timeout, 30_000)
         ) do
      {:ok, %{status: 200, body: response}} ->
        decode(response)

      {:ok, %{status: status, body: response}} ->
        {:error, {:provider_error, status, inspect(response)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode(%{"content" => [%{"text" => text} | _], "usage" => usage}) do
    text = text |> String.replace(~r/^```json\s*|\s*```$/m, "") |> String.trim()

    case Jason.decode(text) do
      {:ok, content} ->
        {:ok,
         %{
           content: content,
           input_tokens: usage["input_tokens"] || 0,
           output_tokens: usage["output_tokens"] || 0
         }}

      {:error, reason} ->
        {:error, {:invalid_json, reason}}
    end
  end

  defp decode(response), do: {:error, {:unexpected_response, inspect(response)}}
end
