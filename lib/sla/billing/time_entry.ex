defmodule Sla.Billing.TimeEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "time_entries" do
    field :date, :date
    field :minutes, :integer
    field :rate, :decimal
    field :description, :string
    field :billable, :boolean, default: true
    field :started_at, :utc_datetime
    belongs_to :matter, Sla.Matters.Matter
    belongs_to :user, Sla.Accounts.User
    belongs_to :invoice_line, Sla.Billing.InvoiceLine
    timestamps(type: :utc_datetime)
  end

  def changeset(record, attrs),
    do:
      record
      |> cast(attrs, [:date, :minutes, :rate, :description, :billable, :started_at])
      |> validate_required([:date, :minutes, :rate, :description])
      |> validate_number(:minutes, greater_than: 0)
      |> validate_number(:rate, greater_than_or_equal_to: 0)
end
