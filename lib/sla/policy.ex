defmodule Sla.Policy do
  @moduledoc "Central role authorization rules."
  alias Sla.Accounts.{Scope, User}

  @permissions %{
    partner: :all,
    admin: :all,
    advocate:
      ~w(clients.read clients.write matters.read matters.write documents.read documents.write)a,
    associate:
      ~w(clients.read clients.write matters.read matters.write documents.read documents.write)a,
    clerk:
      ~w(clients.read clients.write matters.read matters.write documents.read documents.write)a,
    accounts: ~w(clients.read matters.read documents.read billing.read billing.write)a
  }

  def authorize(%Scope{user: %User{active: true, role: role}}, action) when is_binary(role) do
    permissions = Map.get(@permissions, String.to_existing_atom(role), [])
    permissions == :all or action in permissions
  rescue
    ArgumentError -> false
  end

  def authorize(_, _), do: false
  def admin?(%Scope{} = scope), do: authorize(scope, :users_manage)
end
