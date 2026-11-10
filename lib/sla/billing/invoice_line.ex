defmodule Sla.Billing.InvoiceLine do
  use Ecto.Schema
  import Ecto.Changeset

  schema "invoice_lines" do
    field :description, :string
    field :quantity, :decimal, default: 1
    field :unit_price, :decimal
    field :vat_rate, :decimal, default: 16
    field :source, :string
    field :source_id, :integer
    belongs_to :invoice, Sla.Billing.Invoice
    timestamps(type: :utc_datetime)
  end

  def changeset(record, attrs),
    do:
      record
      |> cast(attrs, [:description, :quantity, :unit_price, :vat_rate, :source, :source_id])
      |> validate_required([:description, :quantity, :unit_price, :vat_rate, :source])
      |> validate_number(:quantity, greater_than: 0)
      |> validate_number(:unit_price, greater_than_or_equal_to: 0)
      |> validate_number(:vat_rate, greater_than_or_equal_to: 0)
end
