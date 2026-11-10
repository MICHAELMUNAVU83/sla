defmodule Sla.ClientsTest do
  use Sla.DataCase, async: true
  alias Sla.Clients

  test "creates, filters, updates, and preloads a client" do
    assert {:ok, client} =
             Clients.create_client(%{
               type: "company",
               name: "Acme Kenya Ltd",
               kra_pin: "P051234567A",
               kyc_status: "pending"
             })

    assert [found] = Clients.list_clients(%{"search" => "Acme", "type" => "company"})
    assert found.id == client.id

    assert {:ok, contact} =
             Clients.create_contact(client, %{
               name: "Jane Director",
               email: "jane@acme.test",
               primary: true
             })

    assert contact.client_id == client.id
    assert {:ok, updated} = Clients.update_client(client, %{name: "Acme Legal Kenya Ltd"})
    assert updated.name == "Acme Legal Kenya Ltd"
    assert [%{name: "Jane Director"}] = Clients.get_client!(client.id).contacts
  end

  test "rejects invalid client data" do
    assert {:error, changeset} = Clients.create_client(%{type: "unknown", name: ""})
    assert %{type: [_], name: [_]} = errors_on(changeset)
  end
end
