defmodule Sla.Integrations.PortalMessage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portal_messages" do
    field :body, :string
    field :from_client, :boolean
    field :read_at, :utc_datetime
    belongs_to :client, Sla.Clients.Client
    belongs_to :matter, Sla.Matters.Matter
    belongs_to :portal_account, Sla.Integrations.PortalAccount
    belongs_to :user, Sla.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body, :read_at])
    |> validate_required([:body, :from_client, :client_id, :matter_id])
    |> validate_length(:body, max: 10_000)
  end
end
