defmodule Sla.Billing do
  @moduledoc "Billing, WIP, invoices, allocations, receipts, and financial reporting."
  import Ecto.Query
  alias Ecto.Multi
  alias Sla.{AccountsFinance, Repo}

  alias Sla.Billing.{
    Disbursement,
    FeeAgreement,
    Invoice,
    InvoiceLine,
    Payment,
    PaymentAllocation,
    TimeEntry
  }

  def change_fee_agreement(record \\ %FeeAgreement{}, attrs \\ %{}),
    do: FeeAgreement.changeset(record, attrs)

  def upsert_fee_agreement(matter, attrs),
    do:
      (Repo.get_by(FeeAgreement, matter_id: matter.id) || %FeeAgreement{matter_id: matter.id})
      |> FeeAgreement.changeset(attrs)
      |> Repo.insert_or_update()

  def get_fee_agreement(matter_id), do: Repo.get_by(FeeAgreement, matter_id: matter_id)

  def create_time_entry(matter, user, attrs),
    do:
      %TimeEntry{matter_id: matter.id, user_id: user.id}
      |> TimeEntry.changeset(attrs)
      |> Repo.insert()

  def create_disbursement(matter, attrs),
    do: %Disbursement{matter_id: matter.id} |> Disbursement.changeset(attrs) |> Repo.insert()

  def change_time_entry(attrs \\ %{}), do: TimeEntry.changeset(%TimeEntry{}, attrs)
  def change_disbursement(attrs \\ %{}), do: Disbursement.changeset(%Disbursement{}, attrs)

  def list_unbilled(matter_id) do
    time =
      Repo.all(
        from t in TimeEntry,
          where: t.matter_id == ^matter_id and t.billable and is_nil(t.invoice_line_id),
          preload: [:user],
          order_by: [desc: t.date]
      )

    disbursements =
      Repo.all(
        from d in Disbursement,
          where: d.matter_id == ^matter_id and d.rebillable and is_nil(d.invoice_line_id),
          order_by: [desc: d.date]
      )

    {time, disbursements}
  end

  def create_invoice_from_wip(user, matter, attrs \\ %{}) do
    {time, disbursements} = list_unbilled(matter.id)
    agreement = get_fee_agreement(matter.id)

    fixed =
      if agreement && agreement.type in ~w(fixed retainer milestone) && agreement.amount,
        do: [
          %{
            description: "Agreed professional fees",
            quantity: Decimal.new(1),
            unit_price: agreement.amount,
            vat_rate: Decimal.new(16),
            source: "fixed",
            source_id: agreement.id
          }
        ],
        else: []

    lines =
      Enum.map(
        time,
        &%{
          description: &1.description,
          quantity: Decimal.div(Decimal.new(&1.minutes), 60),
          unit_price: &1.rate,
          vat_rate: Decimal.new(16),
          source: "time",
          source_id: &1.id
        }
      ) ++
        Enum.map(
          disbursements,
          &%{
            description: &1.description,
            quantity: Decimal.new(1),
            unit_price: &1.amount,
            vat_rate: Decimal.new(if(&1.vat_applicable, do: 16, else: 0)),
            source: "disbursement",
            source_id: &1.id
          }
        ) ++ fixed

    if lines == [],
      do: {:error, :no_unbilled_work},
      else: insert_invoice(user, matter, attrs, lines)
  end

  def approve_invoice(invoice, user) when user.role in ~w(partner admin),
    do:
      invoice
      |> Ecto.Changeset.change(
        status: "approved",
        approved_by_id: user.id,
        approved_at: DateTime.utc_now(:second)
      )
      |> Repo.update()

  def approve_invoice(_invoice, _user), do: {:error, :unauthorized}

  def issue_invoice(%Invoice{status: "approved"} = invoice, user) do
    Repo.transact(fn ->
      number = next_number(invoice.type)
      issued_on = invoice.issued_on || Date.utc_today()

      invoice =
        invoice
        |> Ecto.Changeset.change(
          status: "issued",
          number: number,
          issued_on: issued_on,
          due_on: invoice.due_on || Date.add(issued_on, 30),
          issued_at: DateTime.utc_now(:second)
        )
        |> Repo.update!()

      AccountsFinance.audit(user, "invoice.issued", "Invoice", invoice.id, %{number: number})
      {:ok, invoice}
    end)
  end

  def issue_invoice(_, _), do: {:error, :invoice_must_be_approved}

  def record_payment(user, client, attrs, allocations) do
    Multi.new()
    |> Multi.run(:receipt_number, fn _repo, _ -> {:ok, next_number("receipt")} end)
    |> Multi.insert(:payment, fn %{receipt_number: number} ->
      %Payment{client_id: client.id, receipt_number: number} |> Payment.changeset(attrs)
    end)
    |> Multi.run(:allocations, fn repo, %{payment: payment} ->
      allocate(repo, payment, allocations)
    end)
    |> Multi.run(:audit, fn _repo, %{payment: payment} ->
      {:ok,
       AccountsFinance.audit(user, "payment.recorded", "Payment", payment.id, %{
         receipt: payment.receipt_number
       })}
    end)
    |> Repo.transact()
  end

  def get_invoice!(id),
    do:
      Invoice
      |> Repo.get!(id)
      |> Repo.preload([:client, :matter, :lines, allocations: [:payment]])

  def list_invoices,
    do:
      Repo.all(
        from i in Invoice,
          preload: [:client, :matter, :lines, allocations: [:payment]],
          order_by: [desc: i.inserted_at]
      )

  def matter_summary(matter_id),
    do: summary(from i in Invoice, where: i.matter_id == ^matter_id, select: i)

  def client_summary(client_id),
    do: summary(from i in Invoice, where: i.client_id == ^client_id, select: i)

  def aged_debtors(as_of \\ Date.utc_today()) do
    list_invoices()
    |> Enum.filter(&(&1.status in ~w(issued partially_paid) and Decimal.gt?(outstanding(&1), 0)))
    |> Enum.map(fn invoice ->
      Map.put(
        invoice,
        :age_bucket,
        age_bucket(Date.diff(as_of, invoice.due_on || invoice.issued_on || as_of))
      )
    end)
  end

  def outstanding(invoice),
    do:
      Decimal.sub(
        invoice.total,
        Enum.reduce(invoice.allocations, Decimal.new(0), &Decimal.add(&2, &1.amount))
      )

  defp insert_invoice(user, matter, attrs, lines) do
    totals = totals(lines)

    Multi.new()
    |> Multi.insert(
      :invoice,
      %Invoice{client_id: matter.client_id, matter_id: matter.id}
      |> Invoice.changeset(Map.merge(attrs, totals))
    )
    |> Multi.run(:lines, fn repo, %{invoice: invoice} ->
      Enum.reduce_while(lines, {:ok, []}, fn attrs, {:ok, acc} ->
        case repo.insert(%InvoiceLine{invoice_id: invoice.id} |> InvoiceLine.changeset(attrs)) do
          {:ok, line} -> link_source(repo, line)
          {:error, error} -> {:halt, {:error, error}}
        end
        |> case do
          {:ok, line} -> {:cont, {:ok, [line | acc]}}
          error -> {:halt, error}
        end
      end)
    end)
    |> Multi.run(:audit, fn _repo, %{invoice: invoice} ->
      {:ok, AccountsFinance.audit(user, "invoice.created", "Invoice", invoice.id)}
    end)
    |> Repo.transact()
  end

  defp link_source(repo, %{source: "time", source_id: id} = line),
    do:
      repo.get!(TimeEntry, id) |> Ecto.Changeset.change(invoice_line_id: line.id) |> repo.update()

  defp link_source(repo, %{source: "disbursement", source_id: id} = line),
    do:
      repo.get!(Disbursement, id)
      |> Ecto.Changeset.change(invoice_line_id: line.id)
      |> repo.update()

  defp link_source(_repo, line), do: {:ok, line}

  defp totals(lines) do
    subtotal =
      Enum.reduce(lines, Decimal.new(0), fn l, acc ->
        Decimal.add(acc, Decimal.mult(l.quantity, l.unit_price))
      end)

    vat =
      Enum.reduce(lines, Decimal.new(0), fn l, acc ->
        Decimal.add(
          acc,
          Decimal.mult(Decimal.mult(l.quantity, l.unit_price), Decimal.div(l.vat_rate, 100))
        )
      end)

    %{subtotal: subtotal, vat: vat, total: Decimal.add(subtotal, vat)}
  end

  defp allocate(repo, payment, allocations) do
    requested =
      Enum.reduce(
        allocations,
        Decimal.new(0),
        &Decimal.add(&2, Decimal.new(to_string(&1.amount)))
      )

    if Decimal.gt?(requested, Decimal.add(payment.amount, payment.withholding_tax)) do
      {:error, :allocation_exceeds_payment}
    else
      Enum.reduce_while(allocations, {:ok, []}, fn allocation, {:ok, acc} ->
        invoice = get_invoice!(allocation.invoice_id)
        amount = Decimal.new(to_string(allocation.amount))

        cond do
          invoice.client_id != payment.client_id ->
            {:halt, {:error, :client_mismatch}}

          Decimal.gt?(amount, outstanding(invoice)) ->
            {:halt, {:error, :allocation_exceeds_invoice}}

          true ->
            case repo.insert(
                   %PaymentAllocation{payment_id: payment.id}
                   |> PaymentAllocation.changeset(%{invoice_id: invoice.id, amount: amount})
                 ) do
              {:ok, _item} -> update_invoice_status(repo, invoice, amount)
              {:error, error} -> {:error, error}
            end
            |> case do
              {:ok, item} -> {:cont, {:ok, [item | acc]}}
              error -> {:halt, error}
            end
        end
      end)
    end
  end

  defp update_invoice_status(repo, invoice, amount) do
    remaining = Decimal.sub(outstanding(invoice), amount)
    status = if Decimal.compare(remaining, 0) == :eq, do: "paid", else: "partially_paid"
    repo.update(Ecto.Changeset.change(invoice, status: status))
  end

  defp next_number(type) do
    year = Date.utc_today().year

    %{rows: [[value]]} =
      Repo.query!(
        "INSERT INTO document_sequences (type, year, value) VALUES ($1, $2, 1) ON CONFLICT (type, year) DO UPDATE SET value = document_sequences.value + 1 RETURNING value",
        [type, year]
      )

    prefix =
      %{"tax" => "INV", "proforma" => "PF", "credit_note" => "CN", "receipt" => "RCT"}[type] ||
        String.upcase(type)

    "#{prefix}/#{year}/#{String.pad_leading(to_string(value), 5, "0")}"
  end

  defp summary(query) do
    invoices = query |> preload([:lines, allocations: :payment]) |> Repo.all()
    billed = Enum.reduce(invoices, Decimal.new(0), &Decimal.add(&2, &1.total))
    outstanding = Enum.reduce(invoices, Decimal.new(0), &Decimal.add(&2, outstanding(&1)))
    %{billed: billed, paid: Decimal.sub(billed, outstanding), outstanding: outstanding}
  end

  defp age_bucket(days) when days <= 30, do: "0–30"
  defp age_bucket(days) when days <= 60, do: "31–60"
  defp age_bucket(days) when days <= 90, do: "61–90"
  defp age_bucket(_), do: "90+"
end
