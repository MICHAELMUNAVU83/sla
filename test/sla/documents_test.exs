defmodule Sla.DocumentsTest do
  use Sla.DataCase, async: true
  import Sla.AccountsFixtures
  alias Sla.{Clients, Documents, Matters, Repo, Tracker}

  setup do
    owner = user_fixture(%{name: "Matter Owner", role: "advocate"})
    outsider = user_fixture(%{name: "Outsider", role: "associate"})
    partner = user_fixture(%{name: "Partner", role: "partner"})
    {:ok, client} = Clients.create_client(%{type: "company", name: "Document Client"})

    {:ok, matter} =
      Matters.create_matter(%{
        client_id: client.id,
        title: "Document matter",
        practice_area: "corporate_commercial",
        status: "open",
        opened_on: Date.utc_today(),
        responsible_advocate_id: owner.id
      })

    category = Documents.list_categories() |> hd()

    upload = %{
      storage_key: "test/#{System.unique_integer([:positive])}/agreement.txt",
      filename: "agreement.txt",
      content_type: "text/plain",
      size: 12,
      checksum: String.duplicate("a", 64)
    }

    %{
      owner: owner,
      outsider: outsider,
      partner: partner,
      client: client,
      matter: matter,
      category: category,
      upload: upload
    }
  end

  test "creates a versioned matter document, indexes it, and logs an activity", ctx do
    attrs = %{
      client_id: ctx.client.id,
      matter_id: ctx.matter.id,
      category_id: ctx.category.id,
      title: "Signed Sale Agreement",
      tags: "signed, conveyance",
      extracted_text: "purchase price and completion date"
    }

    assert {:ok, document} = Documents.create_document(ctx.owner, attrs, ctx.upload)
    assert document.current_version.version_no == 1
    assert document.tags == ["signed", "conveyance"]
    assert [found] = Documents.list_documents(ctx.owner, %{"search" => "completion date"})
    assert found.id == document.id

    assert [%{document_id: id, action_type: "document_received"}] =
             Tracker.list_activities(ctx.matter.id)

    assert id == document.id
  end

  test "adds and restores versions and supports recategorising", ctx do
    {:ok, document} =
      Documents.create_document(
        ctx.owner,
        %{
          client_id: ctx.client.id,
          matter_id: ctx.matter.id,
          category_id: ctx.category.id,
          title: "Pleading"
        },
        ctx.upload
      )

    second = %{
      ctx.upload
      | storage_key: ctx.upload.storage_key <> "-v2",
        filename: "pleading-v2.txt",
        checksum: String.duplicate("b", 64)
    }

    assert {:ok, version} = Documents.add_version(ctx.owner, document, second)
    assert version.version_no == 2
    document = Documents.get_document!(ctx.owner, document.id)
    first = Enum.find(document.versions, &(&1.version_no == 1))
    assert {:ok, restored} = Documents.restore_version(ctx.owner, document, first.id)
    assert restored.current_version_id == first.id
    other_category = Documents.list_categories() |> Enum.at(1)

    assert {:ok, moved} =
             Documents.update_document(ctx.owner, document, %{
               category_id: other_category.id,
               title: document.title,
               client_id: ctx.client.id,
               matter_id: ctx.matter.id
             })

    assert moved.category_id == other_category.id
  end

  test "enforces matter team access while partners retain oversight", ctx do
    {:ok, document} =
      Documents.create_document(
        ctx.owner,
        %{
          client_id: ctx.client.id,
          matter_id: ctx.matter.id,
          category_id: ctx.category.id,
          title: "Restricted evidence"
        },
        ctx.upload
      )

    assert Documents.can_access?(ctx.owner, document)
    refute Documents.can_access?(ctx.outsider, document)
    assert Documents.can_access?(ctx.partner, document)

    assert_raise Sla.Documents.AccessDenied, fn ->
      Documents.get_document!(ctx.outsider, document.id)
    end

    Repo.insert_all("matter_members", [
      %{
        matter_id: ctx.matter.id,
        user_id: ctx.outsider.id,
        inserted_at: DateTime.utc_now(:second)
      }
    ])

    assert Documents.can_access?(ctx.outsider, document)
  end
end
