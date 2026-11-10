defmodule Sla.Billing.Disbursement do
  use Ecto.Schema
  import Ecto.Changeset

  schema "disbursements" do
    field :date, :date
    field :type, :string
    field :description, :string
    field :amount, :decimal
    field :vat_applicable, :boolean, default: false
    field :rebillable, :boolean, default: true
    belongs_to :matter, Sla.Matters.Matter
    belongs_to :receipt_document, Sla.Documents.Document
    belongs_to :invoice_line, Sla.Billing.InvoiceLine
    timestamps(type: :utc_datetime)
  end

  def changeset(record, attrs),
    do:
      record
      |> cast(attrs, [
        :date,
        :type,
        :description,
        :amount,
        :vat_applicable,
        :rebillable,
        :receipt_document_id
      ])
      |> validate_required([:date, :type, :description, :amount])
      |> validate_number(:amount, greater_than: 0)
end
