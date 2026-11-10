defmodule Sla.Documents.DocumentVersion do
  use Ecto.Schema
  import Ecto.Changeset

  schema "document_versions" do
    field :storage_key, :string
    field :filename, :string
    field :content_type, :string
    field :size, :integer
    field :checksum, :string
    field :version_no, :integer
    belongs_to :document, Sla.Documents.Document
    belongs_to :uploaded_by, Sla.Accounts.User
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(version, attrs) do
    version
    |> cast(attrs, [
      :document_id,
      :storage_key,
      :filename,
      :content_type,
      :size,
      :checksum,
      :version_no
    ])
    |> validate_required([
      :document_id,
      :storage_key,
      :filename,
      :content_type,
      :size,
      :checksum,
      :version_no
    ])
    |> validate_number(:size, greater_than: 0)
    |> validate_number(:version_no, greater_than: 0)
    |> unique_constraint([:document_id, :version_no])
  end
end
