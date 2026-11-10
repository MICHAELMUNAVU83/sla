defmodule Sla.Integrations.SignatureRequest do
  use Ecto.Schema
  import Ecto.Changeset

  schema "signature_requests" do
    field :provider, :string
    field :external_id, :string
    field :signer_name, :string
    field :signer_email, :string
    field :status, :string, default: "draft"
    field :sent_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :audit_data, :map, default: %{}
    belongs_to :document, Sla.Documents.Document
    belongs_to :matter, Sla.Matters.Matter
    belongs_to :requested_by, Sla.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(request, attrs) do
    request
    |> cast(attrs, [
      :provider,
      :external_id,
      :signer_name,
      :signer_email,
      :status,
      :sent_at,
      :completed_at,
      :audit_data
    ])
    |> validate_required([:provider, :signer_name, :signer_email, :document_id, :matter_id])
    |> validate_format(:signer_email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_inclusion(:status, ~w(draft sent viewed signed declined expired failed))
    |> unique_constraint([:provider, :external_id])
  end
end
