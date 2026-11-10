defmodule Sla.Integrations.Connection do
  use Ecto.Schema
  import Ecto.Changeset

  @providers ~w(mpesa etims gmail outlook docusign africastalking whatsapp quickbooks sage xero)
  schema "integration_connections" do
    field :provider, :string
    field :status, :string, default: "disconnected"
    field :settings, :map, default: %{}
    field :credentials, :binary, redact: true
    field :last_synced_at, :utc_datetime
    field :last_error, :string
    belongs_to :created_by, Sla.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def providers, do: @providers

  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [:provider, :status, :settings, :last_synced_at, :last_error])
    |> validate_required([:provider, :status])
    |> validate_inclusion(:provider, @providers)
    |> validate_inclusion(:status, ~w(disconnected connected error))
    |> unique_constraint(:provider)
  end
end
