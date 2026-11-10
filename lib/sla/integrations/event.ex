defmodule Sla.Integrations.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "integration_events" do
    field :provider, :string
    field :external_id, :string
    field :kind, :string
    field :status, :string, default: "received"
    field :payload, :map, default: %{}
    field :result, :map, default: %{}
    field :error, :string
    field :processed_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :provider,
      :external_id,
      :kind,
      :status,
      :payload,
      :result,
      :error,
      :processed_at
    ])
    |> validate_required([:provider, :external_id, :kind, :status])
    |> validate_inclusion(:status, ~w(received processed failed ignored))
    |> unique_constraint([:provider, :external_id])
  end
end
