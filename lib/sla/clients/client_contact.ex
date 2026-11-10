defmodule Sla.Clients.ClientContact do
  use Ecto.Schema
  import Ecto.Changeset

  schema "client_contacts" do
    field :name, :string
    field :title, :string
    field :email, :string
    field :phone, :string
    field :primary, :boolean, default: false
    belongs_to :client, Sla.Clients.Client
    timestamps(type: :utc_datetime)
  end

  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:name, :title, :email, :phone, :primary])
    |> validate_required([:name])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, allow_nil: true)
  end
end
