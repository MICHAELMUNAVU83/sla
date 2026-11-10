defmodule Sla.Billing.FeeAgreement do
  use Ecto.Schema
  import Ecto.Changeset
  @types ~w(fixed hourly aro_scale retainer milestone)
  schema "fee_agreements" do
    field :type, :string
    field :amount, :decimal
    field :currency, :string, default: "KES"
    field :terms, :string
    belongs_to :matter, Sla.Matters.Matter
    timestamps(type: :utc_datetime)
  end

  def types, do: @types

  def changeset(record, attrs),
    do:
      record
      |> cast(attrs, [:type, :amount, :currency, :terms])
      |> validate_required([:type, :currency])
      |> validate_inclusion(:type, @types)
      |> validate_number(:amount, greater_than_or_equal_to: 0)
      |> unique_constraint(:matter_id)
end
