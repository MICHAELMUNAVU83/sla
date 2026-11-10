defmodule Sla.IntegrationsTest do
  use Sla.DataCase, async: false
  import Sla.AccountsFixtures
  alias Sla.{Clients, Integrations, Matters, Repo}

  setup do
    partner = user_fixture() |> Ecto.Changeset.change(role: "partner") |> Repo.update!()
    associate = user_fixture() |> Ecto.Changeset.change(role: "associate") |> Repo.update!()

    {:ok, client} =
      Clients.create_client(%{
        type: "individual",
        name: "Portal Client",
        email: "client@example.com"
      })

    {:ok, other_client} = Clients.create_client(%{type: "company", name: "Other Client"})

    {:ok, matter} =
      Matters.create_matter(%{
        client_id: client.id,
        title: "Portal matter",
        practice_area: "dispute_resolution",
        status: "open",
        opened_on: ~D[2026-11-10],
        responsible_advocate_id: partner.id
      })

    {:ok, other_matter} =
      Matters.create_matter(%{
        client_id: other_client.id,
        title: "Private matter",
        practice_area: "corporate_commercial",
        status: "open",
        opened_on: ~D[2026-11-10],
        responsible_advocate_id: partner.id
      })

    %{
      partner: partner,
      associate: associate,
      client: client,
      matter: matter,
      other_matter: other_matter
    }
  end

  test "only firm leaders configure providers", %{partner: partner, associate: associate} do
    assert {:error, :forbidden} = Integrations.configure(associate, "mpesa", %{})

    assert {:ok, connection} =
             Integrations.configure(partner, "mpesa", %{"shortcode" => "123456"})

    assert connection.status == "connected"
  end

  test "webhooks are idempotent", %{} do
    processor = fn _ -> {:ok, %{accepted: true}} end
    assert {:ok, first} = Integrations.receive("gmail", "message-1", "email", %{}, processor)

    assert {:ok, duplicate, :duplicate} =
             Integrations.receive("gmail", "message-1", "email", %{}, processor)

    assert first.id == duplicate.id
  end

  test "portal authentication and matter isolation", %{
    client: client,
    matter: matter,
    other_matter: other_matter
  } do
    assert {:ok, account} =
             Integrations.create_portal_account(client, %{
               email: "CLIENT@example.com",
               password: "long-secure-password"
             })

    assert {:ok, authenticated} =
             Integrations.authenticate_portal("client@example.com", "long-secure-password")

    assert authenticated.client_id == client.id

    assert {:ok, message} =
             Integrations.send_message(account, matter, "Please share the next court date.")

    assert message.from_client

    assert {:error, :forbidden} =
             Integrations.send_message(account, other_matter, "Should not work")

    refute Repo.get_by(Sla.Integrations.PortalMessage, matter_id: other_matter.id)
  end
end
