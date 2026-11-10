defmodule Sla.Practice.KycCheck do
  use Ecto.Schema
  import Ecto.Changeset

  schema "kyc_checks" do
    field :id_verified, :boolean, default: false
    field :kra_pin_verified, :boolean, default: false
    field :cr12_verified, :boolean, default: false
    field :beneficial_owners_verified, :boolean, default: false
    field :source_of_funds_verified, :boolean, default: false
    field :risk_rating, :string, default: "unrated"
    field :notes, :string
    field :reviewed_at, :utc_datetime
    belongs_to :client, Sla.Clients.Client
    belongs_to :reviewed_by, Sla.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(check, attrs) do
    check
    |> cast(attrs, [
      :id_verified,
      :kra_pin_verified,
      :cr12_verified,
      :beneficial_owners_verified,
      :source_of_funds_verified,
      :risk_rating,
      :notes
    ])
    |> validate_required([:risk_rating])
    |> validate_inclusion(:risk_rating, ~w(unrated low medium high prohibited))
  end
end
