defmodule Sla.Billing.PaymentAllocation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "payment_allocations" do
    field :amount, :decimal
    belongs_to :payment, Sla.Billing.Payment
    belongs_to :invoice, Sla.Billing.Invoice
    timestamps(type: :utc_datetime)
  end

  def changeset(record, attrs),
    do:
      record
      |> cast(attrs, [:invoice_id, :amount])
      |> validate_required([:invoice_id, :amount])
      |> validate_number(:amount, greater_than: 0)
      |> unique_constraint([:payment_id, :invoice_id])
end
