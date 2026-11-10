defmodule Sla.Practice.ClientIntake do
  use Ecto.Schema
  import Ecto.Changeset

  schema "client_intakes" do
    field :client_type, :string
    field :name, :string
    field :email, :string
    field :phone, :string
    field :identification_number, :string
    field :kra_pin, :string
    field :address, :string
    field :matter_summary, :string
    field :status, :string, default: "submitted"
    field :consent_given, :boolean, default: false
    belongs_to :client, Sla.Clients.Client
    belongs_to :submitted_by, Sla.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(intake, attrs) do
    intake
    |> cast(attrs, [
      :client_type,
      :name,
      :email,
      :phone,
      :identification_number,
      :kra_pin,
      :address,
      :matter_summary,
      :consent_given
    ])
    |> validate_required([:client_type, :name, :matter_summary, :consent_given])
    |> validate_inclusion(:client_type, ~w(individual company))
    |> validate_acceptance(:consent_given, message: "must be accepted")
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, allow_nil: true)
  end
end
