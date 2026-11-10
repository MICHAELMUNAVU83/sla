defmodule Sla.Integrations.PortalAccount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portal_accounts" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :last_login_at, :utc_datetime
    field :active, :boolean, default: true
    belongs_to :client, Sla.Clients.Client
    timestamps(type: :utc_datetime)
  end

  def registration_changeset(account, attrs) do
    account
    |> cast(attrs, [:email, :password, :active])
    |> update_change(:email, &String.downcase(String.trim(&1)))
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:password, min: 12, max: 72)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  def valid_password?(%__MODULE__{hashed_password: hash, active: true}, password)
      when is_binary(password), do: Bcrypt.verify_pass(password, hash)

  def valid_password?(_, _), do: false

  defp put_password_hash(%{valid?: true, changes: %{password: password}} = changeset),
    do: put_change(changeset, :hashed_password, Bcrypt.hash_pwd_salt(password))

  defp put_password_hash(changeset), do: changeset
end
