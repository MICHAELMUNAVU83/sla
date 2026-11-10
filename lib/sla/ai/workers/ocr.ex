defmodule Sla.AI.Workers.Ocr do
  use Oban.Worker, queue: :ocr, max_attempts: 3, unique: [period: 300]
  alias Sla.{Accounts, AI, Repo}
  alias Sla.Documents.Document

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"document_id" => document_id, "user_id" => user_id}}) do
    document = Document |> Repo.get!(document_id) |> Repo.preload([:matter, :current_version])
    user = Accounts.get_user!(user_id)

    case AI.perform_ocr(document, user) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
