defmodule Sla.Practice.ConflictCheck do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conflict_checks" do
    field :search_terms, {:array, :string}, default: []
    field :matches, :map, default: %{}
    field :result, :string
    field :notes, :string
    field :performed_at, :utc_datetime
    belongs_to :matter, Sla.Matters.Matter
    belongs_to :client_intake, Sla.Practice.ClientIntake
    belongs_to :performed_by, Sla.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(check, attrs) do
    check
    |> cast(attrs, [:search_terms, :matches, :result, :notes, :performed_at])
    |> validate_required([:search_terms, :result, :performed_at])
    |> validate_inclusion(:result, ~w(clear potential_conflict conflict_waived blocked))
  end
end
