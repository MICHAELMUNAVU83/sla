defmodule Sla.AccountsFinance do
  @moduledoc "Trust and office ledgers, reconciliation, reporting, and immutable audit events."
  import Ecto.Query
  alias Ecto.Multi
  alias Sla.{Repo, AccountsFinance.AuditLog}
  alias Sla.AccountsFinance.LedgerEntry

  def trust_balance(matter_id) do
    Repo.one(
      from e in LedgerEntry,
        where: e.matter_id == ^matter_id and e.account == "client",
        select:
          coalesce(
            sum(
              fragment(
                "CASE WHEN ? = 'credit' THEN ? ELSE -? END",
                e.direction,
                e.amount,
                e.amount
              )
            ),
            0
          )
    )
  end

  def post(user, matter, attrs) do
    changeset =
      %LedgerEntry{matter_id: matter.id, posted_by_id: user.id} |> LedgerEntry.changeset(attrs)

    amount = Ecto.Changeset.get_field(changeset, :amount) || Decimal.new(0)
    account = Ecto.Changeset.get_field(changeset, :account)
    direction = Ecto.Changeset.get_field(changeset, :direction)

    if account == "client" and direction == "debit" and
         Decimal.gt?(amount, trust_balance(matter.id)) do
      {:error,
       Ecto.Changeset.add_error(changeset, :amount, "would create a negative trust balance")}
    else
      Repo.transact(
        Multi.new()
        |> Multi.insert(:entry, changeset)
        |> audit_multi(user, "ledger.posted", "LedgerEntry", :entry)
      )
      |> unwrap(:entry)
    end
  end

  def transfer_to_office(user, approver, matter, amount, reference) do
    cond do
      user.id == approver.id ->
        {:error, :independent_approval_required}

      approver.role not in ~w(partner admin) ->
        {:error, :partner_approval_required}

      Decimal.compare(amount, trust_balance(matter.id)) == :gt ->
        {:error, :insufficient_trust_funds}

      not issued_invoice?(matter.id) ->
        {:error, :issued_invoice_required}

      true ->
        group = Ecto.UUID.generate()

        base = %{
          amount: amount,
          currency: "KES",
          description: "Transfer against issued invoice",
          reference: reference,
          posted_on: Date.utc_today(),
          transfer_group: group
        }

        Multi.new()
        |> Multi.insert(
          :client_entry,
          %LedgerEntry{matter_id: matter.id, posted_by_id: user.id, approved_by_id: approver.id}
          |> LedgerEntry.changeset(Map.merge(base, %{account: "client", direction: "debit"}))
        )
        |> Multi.insert(
          :office_entry,
          %LedgerEntry{matter_id: matter.id, posted_by_id: user.id, approved_by_id: approver.id}
          |> LedgerEntry.changeset(Map.merge(base, %{account: "office", direction: "credit"}))
        )
        |> audit_multi(user, "ledger.transferred", "Matter", matter.id)
        |> Repo.transact()
    end
  end

  def list_entries,
    do:
      Repo.all(
        from e in LedgerEntry,
          preload: [:matter, :posted_by, :approved_by],
          order_by: [desc: e.posted_on, desc: e.id]
      )

  def list_audit_logs,
    do:
      Repo.all(from a in AuditLog, preload: [:actor], order_by: [desc: a.occurred_at], limit: 500)

  def audit(user, action, entity_type, entity_id, metadata \\ %{}),
    do:
      Repo.insert!(%AuditLog{
        actor_id: user && user.id,
        action: action,
        entity_type: entity_type,
        entity_id: to_string(entity_id),
        metadata: metadata,
        occurred_at: DateTime.utc_now(:second)
      })

  defp issued_invoice?(matter_id),
    do:
      Repo.exists?(
        from i in Sla.Billing.Invoice,
          where: i.matter_id == ^matter_id and i.status in ["issued", "partially_paid", "paid"]
      )

  defp audit_multi(multi, user, action, type, id),
    do:
      Multi.insert(multi, :audit, fn changes ->
        %AuditLog{
          actor_id: user.id,
          action: action,
          entity_type: type,
          entity_id: to_string(Map.get(changes, id, id) |> entity_id()),
          metadata: %{},
          occurred_at: DateTime.utc_now(:second)
        }
      end)

  defp entity_id(%{id: id}), do: id
  defp entity_id(id), do: id
  defp unwrap({:ok, values}, key), do: {:ok, Map.fetch!(values, key)}
  defp unwrap({:error, _key, reason, _changes}, _), do: {:error, reason}
end
