defmodule Sla.Documents do
  @moduledoc "Client and matter document storage, versions, search, and access control."
  import Ecto.Query, warn: false
  alias Sla.{Repo, Storage, Tracker}
  alias Sla.Accounts.User
  alias Sla.Documents.{Category, Document, DocumentVersion}
  alias Sla.Matters.Matter

  def list_categories(practice_area \\ nil)

  def list_categories(nil),
    do:
      Category
      |> where([c], c.active and is_nil(c.practice_area))
      |> order_by([c], asc: c.position, asc: c.name)
      |> Repo.all()

  def list_categories(practice_area),
    do:
      Category
      |> where([c], c.active and (is_nil(c.practice_area) or c.practice_area == ^practice_area))
      |> order_by([c], asc: c.position, asc: c.name)
      |> Repo.all()

  def create_category(attrs), do: %Category{} |> Category.changeset(attrs) |> Repo.insert()
  def update_category(category, attrs), do: category |> Category.changeset(attrs) |> Repo.update()
  def get_category!(id), do: Repo.get!(Category, id)

  def list_all_categories,
    do:
      Category
      |> where([c], c.active)
      |> order_by([c], asc: c.position, asc: c.name)
      |> Repo.all()

  def list_documents(user, params \\ %{}) do
    Document
    |> join(:inner, [d], c in assoc(d, :client))
    |> join(:left, [d, c], m in assoc(d, :matter))
    |> join(:inner, [d, c, m], cat in assoc(d, :category))
    |> join(:inner, [d, c, m, cat], v in assoc(d, :current_version))
    |> join(:left, [d, c, m, cat, v], mm in "matter_members", on: mm.matter_id == d.matter_id)
    |> preload([d, c, m, cat, v, mm],
      client: c,
      matter: m,
      category: cat,
      current_version: v,
      uploaded_by: []
    )
    |> accessible_query(user)
    |> filter(:client_id, params["client"] || params[:client_id])
    |> filter(:matter_id, params["matter"] || params[:matter_id])
    |> filter(:category_id, params["category"] || params[:category_id])
    |> filter(:uploaded_by_id, params["uploader"] || params[:uploaded_by_id])
    |> date_filter(params["from"], params["to"])
    |> search(params["search"] || "")
    |> order_by([d], desc: d.inserted_at, desc: d.id)
    |> Repo.all()
    |> Enum.reject(&(&1.matter_id && Sla.Practice.walled?(&1.matter_id, user.id)))
  end

  def get_document!(user, id) do
    document =
      Document
      |> Repo.get!(id)
      |> Repo.preload([
        :client,
        :matter,
        :category,
        :current_version,
        versions:
          from(v in DocumentVersion, order_by: [desc: v.version_no], preload: [:uploaded_by])
      ])

    if can_access?(user, document), do: document, else: raise(Sla.Documents.AccessDenied)
  end

  def get_version!(user, id) do
    version = DocumentVersion |> Repo.get!(id) |> Repo.preload(document: [:matter])
    if can_access?(user, version.document), do: version, else: raise(Sla.Documents.AccessDenied)
  end

  def create_document(user, attrs, upload) do
    Repo.transact(fn ->
      with {:ok, document} <-
             %Document{uploaded_by_id: user.id}
             |> Document.changeset(normalize_tags(attrs))
             |> Repo.insert(),
           {:ok, version} <- insert_version(document, user, upload, 1),
           {:ok, document} <-
             document |> Ecto.Changeset.change(current_version_id: version.id) |> Repo.update(),
           :ok <- log_upload(document, user, version) do
        {:ok,
         Repo.preload(document, [:client, :matter, :category, :current_version, :uploaded_by])}
      end
    end)
  end

  def add_version(user, %Document{} = document, upload) do
    if can_access?(user, document) do
      Repo.transact(fn ->
        next_no =
          Repo.one(
            from v in DocumentVersion,
              where: v.document_id == ^document.id,
              select: coalesce(max(v.version_no), 0)
          ) + 1

        with {:ok, version} <- insert_version(document, user, upload, next_no),
             {:ok, _} <-
               document |> Ecto.Changeset.change(current_version_id: version.id) |> Repo.update(),
             :ok <- log_upload(document, user, version),
             do: {:ok, version}
      end)
    else
      {:error, :forbidden}
    end
  end

  def restore_version(user, document, version_id) do
    with true <- can_access?(user, document),
         %DocumentVersion{document_id: document_id} = version when document_id == document.id <-
           Repo.get(DocumentVersion, version_id),
         do: document |> Ecto.Changeset.change(current_version_id: version.id) |> Repo.update(),
         else: (_ -> {:error, :forbidden})
  end

  def update_document(user, document, attrs),
    do:
      if(can_access?(user, document),
        do: document |> Document.changeset(normalize_tags(attrs)) |> Repo.update(),
        else: {:error, :forbidden}
      )

  def can_access?(%User{active: true, role: role}, %Document{matter_id: nil})
      when role in ~w(partner admin advocate associate clerk accounts), do: true

  def can_access?(%User{id: user_id}, %Document{matter_id: matter_id})
      when not is_nil(matter_id) do
    if Sla.Practice.walled?(matter_id, user_id),
      do: false,
      else: can_access_unwalled?(user_id, matter_id)
  end

  def can_access?(_, _), do: false

  defp can_access_unwalled?(user_id, matter_id) do
    user = Repo.get!(User, user_id)

    user.active and
      (user.role in ~w(partner admin) or
         Repo.exists?(
           from m in Matter,
             left_join: mm in "matter_members",
             on: mm.matter_id == m.id,
             where:
               m.id == ^matter_id and
                 (m.responsible_advocate_id == ^user_id or mm.user_id == ^user_id)
         ))
  end

  def upload_from_path(path, meta) do
    body = File.read!(path)
    key = "documents/#{Ecto.UUID.generate()}/#{Path.basename(meta.client_name)}"
    :ok = Storage.put(key, body)

    %{
      storage_key: key,
      filename: meta.client_name,
      content_type: meta.client_type,
      size: byte_size(body),
      checksum: Base.encode16(:crypto.hash(:sha256, body), case: :lower)
    }
  end

  def external_upload(meta, entry),
    do: %{
      storage_key: meta.key,
      filename: entry.client_name,
      content_type: entry.client_type,
      size: entry.client_size,
      checksum: Base.encode16(:crypto.hash(:sha256, meta.key), case: :lower)
    }

  defp insert_version(document, user, upload, version_no),
    do:
      %DocumentVersion{document_id: document.id, uploaded_by_id: user.id}
      |> DocumentVersion.changeset(Map.put(upload, :version_no, version_no))
      |> Repo.insert()

  defp log_upload(%{matter_id: nil}, _user, _version), do: :ok

  defp log_upload(document, user, version) do
    case Tracker.create_activity(Repo.get!(Matter, document.matter_id), user, %{
           "action_type" => "document_received",
           "note" => "Uploaded #{document.title} (v#{version.version_no})",
           "document_id" => document.id
         }) do
      {:ok, _} -> :ok
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp accessible_query(query, %User{role: role}) when role in ~w(partner admin), do: query

  defp accessible_query(query, %User{id: user_id}),
    do:
      where(
        query,
        [d, _c, m, _cat, _v, mm],
        is_nil(d.matter_id) or m.responsible_advocate_id == ^user_id or mm.user_id == ^user_id
      )

  defp accessible_query(query, _), do: where(query, [d], false)
  defp filter(query, _field, value) when value in [nil, ""], do: query
  defp filter(query, field, value), do: where(query, [d], field(d, ^field) == ^value)
  defp date_filter(query, nil, nil), do: query

  defp date_filter(query, from_date, to_date) do
    query =
      if from_date in [nil, ""], do: query, else: where(query, [d], d.inserted_at >= ^from_date)

    if to_date in [nil, ""], do: query, else: where(query, [d], d.inserted_at <= ^to_date)
  end

  defp search(query, ""), do: query

  defp search(query, term),
    do:
      where(
        query,
        [d],
        fragment("search_vector @@ websearch_to_tsquery('english', ?)", ^term)
      )

  defp normalize_tags(attrs) do
    tags = attrs["tags"] || attrs[:tags] || []

    normalized =
      if is_binary(tags),
        do: tags |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")),
        else: tags

    if Map.has_key?(attrs, "tags"),
      do: Map.put(attrs, "tags", normalized),
      else: Map.put(attrs, :tags, normalized)
  end
end
