defmodule Sla.Matters.MatterParty do
  use Ecto.Schema
  import Ecto.Changeset

  @types ~w(opposing_party opposing_counsel court other)

  schema "matter_parties" do
    field :type, :string
    field :name, :string
    field :email, :string
    field :phone, :string
    field :notes, :string
    belongs_to :matter, Sla.Matters.Matter
    timestamps(type: :utc_datetime)
  end

  def types, do: @types

  def changeset(party, attrs) do
    party
    |> cast(attrs, [:type, :name, :email, :phone, :notes])
    |> validate_required([:type, :name])
    |> validate_inclusion(:type, @types)
  end
end
