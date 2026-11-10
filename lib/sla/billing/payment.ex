defmodule Sla.Billing.Payment do
  use Ecto.Schema
  import Ecto.Changeset
  @methods ~w(bank cheque mpesa card cash)
  schema "payments" do
    field :method, :string
    field :reference, :string
    field :amount, :decimal
    field :currency, :string, default: "KES"
    field :received_on, :date
    field :withholding_tax, :decimal, default: 0
    field :receipt_number, :string
    field :external_provider, :string
    field :external_id, :string
    field :phone, :string
    belongs_to :client, Sla.Clients.Client
    has_many :allocations, Sla.Billing.PaymentAllocation
    timestamps(type: :utc_datetime)
  end

  def methods, do: @methods

  def changeset(record, attrs),
    do:
      record
      |> cast(attrs, [
        :method,
        :reference,
        :amount,
        :currency,
        :received_on,
        :withholding_tax,
        :external_provider,
        :external_id,
        :phone
      ])
      |> validate_required([:method, :reference, :amount, :currency, :received_on])
      |> validate_inclusion(:method, @methods)
      |> validate_number(:amount, greater_than: 0)
      |> validate_number(:withholding_tax, greater_than_or_equal_to: 0)
      |> unique_constraint([:external_provider, :external_id])
end
