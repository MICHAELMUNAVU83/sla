defmodule Sla.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset

  schema "documents" do
    field :title, :string
    field :tags, {:array, :string}, default: []
    field :extracted_text, :string
    field :ocr_status, :string, default: "not_requested"
    field :extracted_data, :map, default: %{}
    field :embedding, {:array, :float}
    belongs_to :client, Sla.Clients.Client
    belongs_to :matter, Sla.Matters.Matter
    belongs_to :category, Sla.Documents.Category
    belongs_to :current_version, Sla.Documents.DocumentVersion
    belongs_to :uploaded_by, Sla.Accounts.User
    has_many :versions, Sla.Documents.DocumentVersion
    timestamps(type: :utc_datetime)
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :client_id,
      :matter_id,
      :category_id,
      :title,
      :tags,
      :extracted_text,
      :ocr_status,
      :extracted_data,
      :embedding
    ])
    |> validate_required([:client_id, :category_id, :title])
    |> validate_length(:title, max: 240)
    |> validate_matter_client()
    |> foreign_key_constraint(:client_id)
    |> foreign_key_constraint(:matter_id)
    |> foreign_key_constraint(:category_id)
  end

  defp validate_matter_client(changeset) do
    matter_id = get_field(changeset, :matter_id)
    client_id = get_field(changeset, :client_id)

    if matter_id && client_id do
      case Sla.Repo.get(Sla.Matters.Matter, matter_id) do
        %{client_id: ^client_id} -> changeset
        _ -> add_error(changeset, :matter_id, "does not belong to the selected client")
      end
    else
      changeset
    end
  end
end
