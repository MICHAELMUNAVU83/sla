defmodule Sla.Matters do
  @moduledoc "Legal matters, team assignments, parties, and file numbering."
  import Ecto.Query, warn: false
  alias Sla.Repo
  alias Sla.Matters.{FileNumber, Matter, MatterParty}

  def list_matters(params \\ %{}) do
    Matter
    |> join(:inner, [m], c in assoc(m, :client))
    |> preload([m, c], client: c, responsible_advocate: [])
    |> maybe_filter(:status, Map.get(params, "status", ""))
    |> maybe_filter(:practice_area, Map.get(params, "practice_area", ""))
    |> maybe_filter(:responsible_advocate_id, Map.get(params, "advocate", ""))
    |> maybe_filter(:client_id, Map.get(params, "client", ""))
    |> maybe_search(Map.get(params, "search", ""))
    |> order_by([m], desc: m.opened_on, desc: m.id)
    |> Repo.all()
  end

  def list_matters_for_user(user, params \\ %{}) do
    blocked_ids =
      Repo.all(from w in "ethical_walls", where: w.user_id == ^user.id, select: w.matter_id)
      |> MapSet.new()

    list_matters(params) |> Enum.reject(&MapSet.member?(blocked_ids, &1.id))
  end

  def get_matter!(id),
    do:
      Matter
      |> Repo.get!(id)
      |> Repo.preload([:client, :responsible_advocate, :members, :parties])

  def get_matter_for_user!(id, user) do
    matter = get_matter!(id)

    if Sla.Practice.walled?(matter.id, user.id),
      do: raise(Ecto.NoResultsError, queryable: Matter),
      else: matter
  end

  def change_matter(%Matter{} = matter, attrs \\ %{}), do: Matter.changeset(matter, attrs)

  def create_matter(attrs) do
    Repo.transact(fn ->
      changeset = Matter.changeset(%Matter{}, attrs)

      if changeset.valid? do
        file_number =
          FileNumber.next(
            Ecto.Changeset.get_field(changeset, :practice_area),
            Ecto.Changeset.get_field(changeset, :opened_on)
          )

        changeset |> Ecto.Changeset.put_change(:file_number, file_number) |> Repo.insert()
      else
        {:error, changeset}
      end
    end)
  end

  def create_matter(%Sla.Accounts.Scope{user: user}, attrs) do
    client = Repo.get!(Sla.Clients.Client, attrs["client_id"] || attrs[:client_id])
    terms = [client.name, attrs["title"] || attrs[:title]]
    matches = Sla.Practice.conflict_search(terms, exclude_client_id: client.id)

    if matches.clients == [] and matches.parties == [] do
      Repo.transact(fn ->
        with {:ok, matter} <- create_matter(attrs),
             {:ok, _check} <-
               %Sla.Practice.ConflictCheck{matter_id: matter.id, performed_by_id: user.id}
               |> Sla.Practice.ConflictCheck.changeset(%{
                 search_terms: terms,
                 matches: matches,
                 result: "clear",
                 notes: "Automatic pre-opening conflict check",
                 performed_at: DateTime.utc_now(:second)
               })
               |> Repo.insert() do
          {:ok, matter}
        end
      end)
    else
      changeset =
        %Matter{}
        |> Matter.changeset(attrs)
        |> Ecto.Changeset.add_error(
          :title,
          "cannot be opened until potential conflicts are reviewed"
        )

      {:error, changeset}
    end
  end

  def update_matter(%Matter{} = matter, attrs),
    do: matter |> Matter.changeset(attrs) |> Repo.update()

  def delete_matter(%Matter{} = matter), do: Repo.delete(matter)

  def create_party(%Matter{} = matter, attrs) do
    %MatterParty{matter_id: matter.id} |> MatterParty.changeset(attrs) |> Repo.insert()
  end

  defp maybe_filter(query, _field, ""), do: query
  defp maybe_filter(query, field, value), do: where(query, [m], field(m, ^field) == ^value)
  defp maybe_search(query, ""), do: query

  defp maybe_search(query, term),
    do:
      where(
        query,
        [m, c],
        ilike(m.title, ^"%#{term}%") or ilike(m.file_number, ^"%#{term}%") or
          ilike(c.name, ^"%#{term}%")
      )
end
