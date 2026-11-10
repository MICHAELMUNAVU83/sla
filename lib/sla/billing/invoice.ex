defmodule Sla.Billing.Invoice do
  use Ecto.Schema
  import Ecto.Changeset
  @types ~w(proforma tax credit_note)
  @statuses ~w(draft approved issued partially_paid paid void)
  schema "invoices" do
    field :number, :string
    field :type, :string, default: "tax"
    field :status, :string, default: "draft"
    field :currency, :string, default: "KES"
    field :issued_on, :date
    field :due_on, :date
    field :subtotal, :decimal, default: 0
    field :vat, :decimal, default: 0
    field :total, :decimal, default: 0
    field :approved_at, :utc_datetime
    field :issued_at, :utc_datetime
    field :etims_control_number, :string
    field :etims_qr_data, :string
    field :etims_status, :string
    field :etims_submitted_at, :utc_datetime
    belongs_to :client, Sla.Clients.Client
    belongs_to :matter, Sla.Matters.Matter
    belongs_to :approved_by, Sla.Accounts.User
    has_many :lines, Sla.Billing.InvoiceLine
    has_many :allocations, Sla.Billing.PaymentAllocation
    timestamps(type: :utc_datetime)
  end

  def types, do: @types
  def statuses, do: @statuses

  def changeset(record, attrs),
    do:
      record
      |> cast(attrs, [:type, :status, :currency, :issued_on, :due_on, :subtotal, :vat, :total])
      |> validate_required([:type, :status, :currency])
      |> validate_inclusion(:type, @types)
      |> validate_inclusion(:status, @statuses)
end
