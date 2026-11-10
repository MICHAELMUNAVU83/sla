defmodule Sla.MattersTest do
  use Sla.DataCase, async: true
  alias Sla.{Clients, Matters}

  test "creates sequential file numbers per area and year and supports filters" do
    {:ok, client} = Clients.create_client(%{type: "individual", name: "Amina Wanjiku"})

    attrs = %{
      client_id: client.id,
      title: "Property transfer",
      practice_area: "real_estate",
      status: "open",
      opened_on: ~D[2026-11-10]
    }

    assert {:ok, first} = Matters.create_matter(attrs)
    assert {:ok, second} = Matters.create_matter(%{attrs | title: "Second transfer"})
    assert first.file_number == "SLA/RE/2026/0001"
    assert second.file_number == "SLA/RE/2026/0002"

    assert [_, _] =
             Matters.list_matters(%{"practice_area" => "real_estate", "client" => client.id})
  end

  test "requires a valid client and practice area" do
    assert {:error, changeset} =
             Matters.create_matter(%{
               title: "Invalid",
               practice_area: "tax",
               opened_on: ~D[2026-11-10]
             })

    assert %{client_id: [_], practice_area: [_]} = errors_on(changeset)
  end
end
