defmodule Sla.AccountsFinance.AuditLog do
  use Ecto.Schema

  schema "audit_logs" do
    field :action, :string
    field :entity_type, :string
    field :entity_id, :string
    field :metadata, :map, default: %{}
    field :occurred_at, :utc_datetime
    belongs_to :actor, Sla.Accounts.User
  end
end
