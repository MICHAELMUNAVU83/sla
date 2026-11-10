defmodule Sla.PracticeTest do
  use Sla.DataCase, async: false
  import Sla.AccountsFixtures
  alias Sla.{Clients, Matters, Practice, Repo, Tracker}

  setup do
    user = user_fixture(%{name: "Practice Partner", role: "partner"})

    {:ok, client} =
      Clients.create_client(%{type: "company", name: "Acacia Holdings", kra_pin: "P001234567A"})

    {:ok, matter} =
      Matters.create_matter(%{
        client_id: client.id,
        title: "Acquisition",
        practice_area: "real_estate",
        opened_on: ~D[2026-11-10],
        responsible_advocate_id: user.id
      })

    %{user: user, client: client, matter: matter}
  end

  test "captures intake, stores conflict results, and maintains KYC review", %{
    user: user,
    client: client
  } do
    assert {:ok, intake} =
             Practice.create_intake(user, %{
               client_type: "individual",
               name: "Njeri Kamau",
               matter_summary: "Purchase from Acacia Holdings",
               consent_given: true
             })

    assert intake.status == "submitted"

    assert {:ok, check} =
             Practice.record_conflict_check(user, %{"search_terms" => "Acacia Holdings"})

    assert check.result == "potential_conflict"
    assert check.matches["clients"] != []

    assert {:ok, kyc} =
             Practice.upsert_kyc(client, user, %{
               id_verified: true,
               kra_pin_verified: true,
               risk_rating: "low"
             })

    assert kyc.id_verified
    assert kyc.reviewed_by_id == user.id
  end

  test "deadline rule creates a deadline event and a bring-up", %{user: user, matter: matter} do
    assert {:ok, _} =
             Practice.create_deadline_rule(%{
               name: "Enter appearance test",
               trigger_event_type: "filing",
               days: 15,
               result_event_type: "deadline"
             })

    assert {:ok, event} =
             Practice.create_event(user, %{
               matter_id: matter.id,
               assigned_to_id: user.id,
               title: "Served with summons",
               event_type: "filing",
               starts_at: ~U[2026-11-10 09:00:00Z]
             })

    assert event.event_type == "filing"

    assert Enum.any?(
             Practice.list_events(%{matter_id: matter.id}),
             &(&1.title == "Enter appearance test")
           )

    assert Enum.any?(Tracker.diary(user.id).upcoming, &(&1.note == "Enter appearance test"))
  end

  test "workflow generates ordered tasks and completing one logs activity", %{
    user: user,
    matter: matter
  } do
    assert {:ok, workflow} =
             Practice.create_workflow(
               %{
                 name: "Test purchase workflow",
                 practice_area: "real_estate",
                 matter_type: "purchase"
               },
               [
                 %{title: "Search title", days_from_start: 2},
                 %{title: "Draft transfer", days_from_start: 5}
               ]
             )

    assert {:ok, tasks} = Practice.apply_workflow(matter, user, workflow.id, ~D[2026-11-10])
    assert Enum.map(tasks, & &1.due_on) == [~D[2026-11-12], ~D[2026-11-15]]
    assert {:ok, completed} = Practice.complete_task(hd(tasks).id, user)
    assert completed.status == "completed"

    assert Enum.any?(
             Tracker.list_activities(matter.id),
             &(&1.note == "Completed task: Search title")
           )
  end

  test "assembles escaped documents, enforces ethical walls, and requires closing checklist", %{
    user: user,
    matter: matter
  } do
    assert {:ok, template} =
             Practice.create_document_template(%{
               name: "Test letter",
               format: "html",
               body: "<p>{{client.name}} — {{matter.file_number}}</p>"
             })

    assert Practice.assemble_document(template.id, matter) =~ "Acacia Holdings"
    assert {:ok, <<"PK", _::binary>>} = Practice.assemble_docx(template.id, matter)

    blocked_user = user_fixture(%{role: "associate"})

    assert {1, nil} =
             Practice.add_ethical_wall(matter, blocked_user.id, user, "Adverse former client")

    assert Practice.walled?(matter.id, blocked_user.id)

    assert_raise Ecto.NoResultsError, fn ->
      Matters.get_matter_for_user!(matter.id, blocked_user)
    end

    assert {:error, :incomplete_closing_checklist} =
             Practice.archive_matter(matter, ~D[2033-11-10])

    items = Practice.list_closing_items(matter.id)
    Enum.each(items, &Practice.toggle_closing_item(&1.id, user))
    assert {:ok, archived} = Practice.archive_matter(Repo.reload!(matter), ~D[2033-11-10])
    assert archived.status == "archived"
  end
end
