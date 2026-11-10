defmodule Sla.AccountsFinance.LedgerEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ledger_entries" do
    field :account, :string
    field :direction, :string
    field :amount, :decimal
    field :currency, :string, default: "KES"
    field :description, :string
    field :reference, :string
    field :transfer_group, Ecto.UUID
    field :posted_on, :date
    belongs_to :matter, Sla.Matters.Matter
    belongs_to :approved_by, Sla.Accounts.User
    belongs_to :posted_by, Sla.Accounts.User
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(record, attrs),
    do:
      record
      |> cast(attrs, [
        :account,
        :direction,
        :amount,
        :currency,
        :description,
        :reference,
        :posted_on,
        :transfer_group
      ])
      |> validate_required([:account, :direction, :amount, :currency, :description, :posted_on])
      |> validate_inclusion(:account, ~w(client office))
      |> validate_inclusion(:direction, ~w(debit credit))
      |> validate_number(:amount, greater_than: 0)
end
