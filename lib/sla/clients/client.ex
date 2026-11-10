defmodule Sla.Clients.Client do
  use Ecto.Schema
  import Ecto.Changeset

  @types ~w(individual company)
  @kyc_statuses ~w(pending in_review verified rejected)

  schema "clients" do
    field :type, :string
    field :name, :string
    field :kra_pin, :string
    field :identification_number, :string
    field :email, :string
    field :phone, :string
    field :address, :string
    field :kyc_status, :string, default: "pending"
    has_many :contacts, Sla.Clients.ClientContact
    has_many :matters, Sla.Matters.Matter
    timestamps(type: :utc_datetime)
  end

  def types, do: @types
  def kyc_statuses, do: @kyc_statuses

  def changeset(client, attrs) do
    client
    |> cast(attrs, [
      :type,
      :name,
      :kra_pin,
      :identification_number,
      :email,
      :phone,
      :address,
      :kyc_status
    ])
    |> update_change(:name, &String.trim/1)
    |> update_change(:kra_pin, &blank_to_nil/1)
    |> validate_required([:type, :name, :kyc_status])
    |> validate_inclusion(:type, @types)
    |> validate_inclusion(:kyc_status, @kyc_statuses)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, allow_nil: true)
    |> unique_constraint(:kra_pin)
  end

  defp blank_to_nil(value) when is_binary(value),
    do: if(String.trim(value) == "", do: nil, else: String.trim(value))

  defp blank_to_nil(value), do: value
end
