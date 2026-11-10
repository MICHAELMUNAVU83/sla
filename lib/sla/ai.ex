defmodule Sla.AI do
  @moduledoc "Firm-controlled AI assistance with durable human review and usage auditing."
  import Ecto.Query, warn: false
  alias Sla.{Repo, Storage}
  alias Sla.AI.{Output, Setting, UsageLog}
  alias Sla.Documents.{Category, Document}
  alias Sla.Tracker.{BringUp, FileActivity}

  def settings, do: Repo.one(from s in Setting, limit: 1) || %Setting{}
  def enabled?, do: settings().enabled
  def change_settings(attrs \\ %{}), do: Setting.changeset(settings(), attrs)

  def update_settings(user, attrs) when user.role in ~w(partner admin) do
    setting = settings()

    setting
    |> Setting.changeset(Map.put(attrs, "updated_by_id", user.id))
    |> then(fn changeset ->
      if setting.id, do: Repo.update(changeset), else: Repo.insert(changeset)
    end)
  end

  def update_settings(_, _), do: {:error, :forbidden}

  def list_outputs(filters \\ %{}) do
    Output
    |> filter(:matter_id, filters[:matter_id])
    |> filter(:document_id, filters[:document_id])
    |> filter(:status, filters[:status])
    |> order_by([o], desc: o.inserted_at)
    |> preload([:matter, :document, :requested_by, :reviewed_by])
    |> Repo.all()
  end

  def latest_output(matter_id, kind) do
    Repo.one(
      from o in Output,
        where: o.matter_id == ^matter_id and o.kind == ^kind,
        order_by: [desc: o.inserted_at],
        limit: 1
    )
  end

  def generate_matter_summary(matter, user),
    do:
      run(
        "matter_summary",
        matter,
        nil,
        user,
        "Summarise current status, work completed, risks and next deadline. #{matter_context(matter.id)}"
      )

  def suggest_next_action(matter, user),
    do:
      run(
        "next_action",
        matter,
        nil,
        user,
        "Suggest one next_action, rationale and bring_up_date (YYYY-MM-DD). #{matter_context(matter.id)}"
      )

  def classify_document(document, user),
    do:
      run(
        "classification",
        document.matter,
        document,
        user,
        "Classify this document. Return category_name, suggested_matter_id, confidence, rationale. " <>
          document_context(document)
      )

  def extract_document(document, user),
    do:
      run(
        "extraction",
        document.matter,
        document,
        user,
        "Extract parties, dates, amounts, title_numbers and case_numbers. Use arrays and omit unknowns. " <>
          document_context(document)
      )

  def summarize_document(document, user),
    do:
      run(
        "document_summary",
        document.matter,
        document,
        user,
        "Summarise this document, obligations, deadlines and risks. #{document_context(document)}"
      )

  def draft(matter, user, type, instructions),
    do:
      run(
        "draft",
        matter,
        nil,
        user,
        "Draft a #{type}. Instructions: #{instructions}. Return subject and body. #{matter_context(matter.id)}"
      )

  def suggest_time(matter, user),
    do:
      run(
        "time_suggestion",
        matter,
        nil,
        user,
        "Suggest unrecorded time entries from recent activity. Return suggestions with date, minutes and description. " <>
          matter_context(matter.id)
      )

  def collections_insight(matter, user),
    do:
      run(
        "collection_insight",
        matter,
        nil,
        user,
        "Assess collection risk and draft a courteous payment reminder. Return risk, reasons, subject, body. " <>
          matter_context(matter.id)
      )

  def accept_output(%Output{} = output, user) do
    with :ok <- authorize_output(output, user) do
      Repo.transact(fn ->
        with {:ok, _} <- apply_output(output, user),
             {:ok, reviewed} <- review(output, user, "accepted"),
             do: {:ok, reviewed}
      end)
    end
  end

  def reject_output(output, user) do
    with :ok <- authorize_output(output, user), do: review(output, user, "rejected")
  end

  def natural_language_search(user, query) do
    terms =
      query
      |> String.replace(~r/[^[:alnum:]\s-]/u, " ")
      |> String.split()
      |> Enum.reject(&(String.length(&1) < 3))
      |> Enum.take(8)
      |> Enum.join(" OR ")

    if terms == "", do: [], else: Sla.Documents.list_documents(user, %{"search" => terms})
  end

  def enqueue_ocr(document, user),
    do: %{document_id: document.id, user_id: user.id} |> Sla.AI.Workers.Ocr.new() |> Oban.insert()

  def perform_ocr(document, user) do
    version = Repo.preload(document, :current_version).current_version

    with {:ok, binary} <- Storage.read(version.storage_key),
         {:ok, output} <-
           run(
             "extraction",
             document.matter,
             document,
             user,
             ("OCR and extract readable text from this file payload. Return text and key_data. Payload: " <>
                Base.encode64(binary, padding: false))
             |> String.slice(0, 60_000)
           ) do
      document |> Document.changeset(%{ocr_status: "review_required"}) |> Repo.update()
      {:ok, output}
    else
      error ->
        document |> Document.changeset(%{ocr_status: "failed"}) |> Repo.update()
        error
    end
  end

  defp run(kind, matter, document, user, prompt) do
    setting = settings()

    if setting.enabled do
      started = System.monotonic_time(:millisecond)
      provider = Application.get_env(:sla, __MODULE__, []) |> Keyword.get(:provider, Sla.AI.Claude)
      result = provider.generate(prompt, model: setting.model)
      duration = System.monotonic_time(:millisecond) - started
      log_usage(result, kind, setting.model, duration, user, matter)

      case result do
        {:ok, response} ->
          %Output{}
          |> Output.changeset(%{
            kind: kind,
            content: response.content,
            matter_id: matter && matter.id,
            document_id: document && document.id,
            requested_by_id: user.id
          })
          |> Repo.insert()

        error ->
          error
      end
    else
      {:error, :disabled}
    end
  end

  defp review(output, user, status),
    do:
      output
      |> Output.changeset(%{
        status: status,
        reviewed_by_id: user.id,
        reviewed_at: DateTime.utc_now(:second)
      })
      |> Repo.update()

  defp apply_output(%{kind: "classification", document_id: id, content: content}, _user) do
    document = Repo.get!(Document, id)

    category =
      Repo.one(from c in Category, where: ilike(c.name, ^content["category_name"]), limit: 1)

    attrs = %{matter_id: content["suggested_matter_id"] || document.matter_id}
    attrs = if category, do: Map.put(attrs, :category_id, category.id), else: attrs
    document |> Document.changeset(attrs) |> Repo.update()
  end

  defp apply_output(%{kind: "extraction", document_id: id, content: content}, _user) do
    document = Repo.get!(Document, id)
    attrs = %{extracted_data: content, ocr_status: "complete"}
    attrs = if content["text"], do: Map.put(attrs, :extracted_text, content["text"]), else: attrs
    document |> Document.changeset(attrs) |> Repo.update()
  end

  defp apply_output(%{kind: "next_action", matter_id: matter_id, content: content}, user) do
    with {:ok, due_on} <- Date.from_iso8601(content["bring_up_date"] || "") do
      %BringUp{}
      |> BringUp.changeset(%{
        matter_id: matter_id,
        assignee_id: user.id,
        created_by_id: user.id,
        due_on: due_on,
        note: content["next_action"],
        status: "pending"
      })
      |> Repo.insert()
    end
  end

  defp apply_output(_, _), do: {:ok, :no_domain_change}

  defp authorize_output(%{matter_id: matter_id}, user) when not is_nil(matter_id) do
    if Sla.Practice.walled?(matter_id, user.id), do: {:error, :forbidden}, else: :ok
  end

  defp authorize_output(%{document_id: document_id}, user) when not is_nil(document_id) do
    document = Repo.get!(Document, document_id)
    if Sla.Documents.can_access?(user, document), do: :ok, else: {:error, :forbidden}
  end

  defp authorize_output(_, _), do: :ok

  defp matter_context(id) do
    activities =
      Repo.all(
        from a in FileActivity,
          where: a.matter_id == ^id,
          order_by: [desc: a.occurred_at],
          limit: 30,
          select: %{date: a.occurred_at, type: a.action_type, note: a.note}
      )

    "Matter data: " <> Jason.encode!(activities)
  end

  defp document_context(document),
    do:
      "Title: #{document.title}. Existing text: " <>
        String.slice(document.extracted_text || "", 0, 20_000)

  defp log_usage(result, operation, model, duration, user, matter) do
    {success, input, output, error} =
      case result do
        {:ok, data} -> {true, data.input_tokens, data.output_tokens, nil}
        {:error, reason} -> {false, 0, 0, inspect(reason)}
      end

    %UsageLog{}
    |> UsageLog.changeset(%{
      operation: operation,
      model: model,
      input_tokens: input,
      output_tokens: output,
      duration_ms: duration,
      success: success,
      error: error,
      user_id: user.id,
      matter_id: matter && matter.id
    })
    |> Repo.insert()
  end

  defp filter(query, _field, nil), do: query
  defp filter(query, field, value), do: where(query, [o], field(o, ^field) == ^value)
end
