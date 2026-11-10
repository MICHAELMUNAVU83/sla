defmodule Sla.AccountsFinanceTest do
  use Sla.DataCase, async: false
  import Sla.AccountsFixtures
  alias Sla.{AccountsFinance, Clients, Matters, Repo}

  setup do
    poster = user_fixture() |> Ecto.Changeset.change(role: "accounts") |> Repo.update!()
    partner = user_fixture() |> Ecto.Changeset.change(role: "partner") |> Repo.update!()
    {:ok, client} = Clients.create_client(%{type: "company", name: "Trust Client"})

    {:ok, matter} =
      Matters.create_matter(%{
        client_id: client.id,
        title: "Trust matter",
        practice_area: "corporate_commercial",
        status: "open",
        opened_on: ~D[2026-11-10]
      })

    %{poster: poster, partner: partner, matter: matter}
  end

  test "prevents negative trust balances", %{poster: poster, matter: matter} do
    attrs = %{
      account: "client",
      direction: "debit",
      amount: "1",
      currency: "KES",
      description: "Invalid withdrawal",
      posted_on: ~D[2026-11-10]
    }

    assert {:error, changeset} = AccountsFinance.post(poster, matter, attrs)
    assert %{amount: [_]} = errors_on(changeset)
  end

  test "posts a trust deposit and requires an issued invoice for office transfer", %{
    poster: poster,
    partner: partner,
    matter: matter
  } do
    assert {:ok, entry} =
             AccountsFinance.post(poster, matter, %{
               account: "client",
               direction: "credit",
               amount: "5000",
               currency: "KES",
               description: "Client deposit",
               posted_on: ~D[2026-11-10]
             })

    assert entry.amount == Decimal.new("5000")
    assert Decimal.eq?(AccountsFinance.trust_balance(matter.id), Decimal.new("5000"))

    assert {:error, :issued_invoice_required} =
             AccountsFinance.transfer_to_office(
               poster,
               partner,
               matter,
               Decimal.new("1000"),
               "INV-X"
             )
  end
end
