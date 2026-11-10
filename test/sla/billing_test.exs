defmodule Sla.BillingTest do
  use Sla.DataCase, async: false
  import Sla.AccountsFixtures
  alias Sla.{Billing, Clients, Matters, Repo}

  setup do
    user =
      user_fixture() |> Ecto.Changeset.change(role: "partner", name: "Partner") |> Repo.update!()

    {:ok, client} = Clients.create_client(%{type: "individual", name: "Billing Client"})

    {:ok, matter} =
      Matters.create_matter(%{
        client_id: client.id,
        title: "Fee matter",
        practice_area: "real_estate",
        status: "open",
        opened_on: ~D[2026-11-10],
        responsible_advocate_id: user.id
      })

    %{user: user, client: client, matter: matter}
  end

  test "builds WIP invoice with VAT, progresses approval, and allocates payment", %{
    user: user,
    client: client,
    matter: matter
  } do
    assert {:ok, _} =
             Billing.create_time_entry(matter, user, %{
               date: ~D[2026-11-10],
               minutes: 60,
               rate: "10000",
               description: "Draft agreement",
               billable: true
             })

    assert {:ok, _} =
             Billing.create_disbursement(matter, %{
               date: ~D[2026-11-10],
               type: "filing",
               description: "Registry fee",
               amount: "1000",
               vat_applicable: false
             })

    assert {:ok, %{invoice: invoice}} = Billing.create_invoice_from_wip(user, matter)
    invoice = Billing.get_invoice!(invoice.id)
    assert invoice.subtotal == Decimal.new("11000.00")
    assert invoice.vat == Decimal.new("1600.00")
    assert invoice.total == Decimal.new("12600.00")
    assert {:ok, approved} = Billing.approve_invoice(invoice, user)
    assert {:ok, issued} = Billing.issue_invoice(approved, user)
    assert issued.number =~ ~r/^INV\/2026\/\d{5}$/

    assert {:ok, %{payment: payment}} =
             Billing.record_payment(
               user,
               client,
               %{
                 method: "bank",
                 reference: "TX-1",
                 amount: "12600",
                 currency: "KES",
                 received_on: ~D[2026-11-10],
                 withholding_tax: "0"
               },
               [%{invoice_id: issued.id, amount: "12600"}]
             )

    assert payment.receipt_number =~ ~r/^RCT\/2026\/\d{5}$/
    assert Billing.get_invoice!(issued.id).status == "paid"
  end
end
