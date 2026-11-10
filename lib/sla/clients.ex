defmodule Sla.Clients do
  @moduledoc "Client records and company contacts."
  import Ecto.Query, warn: false
  alias Sla.Repo
  alias Sla.Clients.{Client, ClientContact}

  def list_clients(params \\ %{}) do
    search = Map.get(params, "search", "")
    type = Map.get(params, "type", "")

    Client
    |> maybe_search(search)
    |> maybe_type(type)
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  def list_clients_with_matters, do: list_clients() |> Repo.preload(:matters)

  def get_client!(id), do: Client |> Repo.get!(id) |> Repo.preload([:contacts, :matters])
  def create_client(attrs), do: %Client{} |> Client.changeset(attrs) |> Repo.insert()

  def update_client(%Client{} = client, attrs),
    do: client |> Client.changeset(attrs) |> Repo.update()

  def delete_client(%Client{} = client), do: Repo.delete(client)
  def change_client(%Client{} = client, attrs \\ %{}), do: Client.changeset(client, attrs)

  def create_contact(%Client{} = client, attrs) do
    %ClientContact{client_id: client.id} |> ClientContact.changeset(attrs) |> Repo.insert()
  end

  defp maybe_search(query, ""), do: query

  defp maybe_search(query, term),
    do:
      where(
        query,
        [c],
        ilike(c.name, ^"%#{term}%") or ilike(c.email, ^"%#{term}%") or
          ilike(c.kra_pin, ^"%#{term}%")
      )

  defp maybe_type(query, type) when type in ["individual", "company"],
    do: where(query, [c], c.type == ^type)

  defp maybe_type(query, _), do: query
end
