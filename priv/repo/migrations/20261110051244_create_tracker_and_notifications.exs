defmodule Sla.Repo.Migrations.CreateTrackerAndNotifications do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :notification_preferences, :map,
        null: false,
        default: %{"in_app" => true, "email" => true}
    end

    alter table(:matters) do
      add :last_activity_at, :utc_datetime
      add :last_activity_summary, :string
      add :dormant_alerted_at, :utc_datetime
    end

    create index(:matters, [:status, :last_activity_at])

    create table(:file_activities) do
      add :matter_id, references(:matters, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :restrict), null: false
      add :action_type, :string, null: false
      add :note, :text, null: false
      add :occurred_at, :utc_datetime, null: false
      add :document_id, :bigint
      add :email_ref, :string
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:file_activities, [:matter_id, :occurred_at])
    create index(:file_activities, [:user_id])

    create constraint(:file_activities, :file_activities_action_type_check,
             check:
               "action_type IN ('email_sent', 'email_received', 'call', 'meeting', 'filing', 'court_attendance', 'letter', 'document_received', 'note', 'other')"
           )

    create table(:bring_ups) do
      add :matter_id, references(:matters, on_delete: :delete_all), null: false
      add :activity_id, references(:file_activities, on_delete: :nilify_all)
      add :assignee_id, references(:users, on_delete: :restrict), null: false
      add :created_by_id, references(:users, on_delete: :restrict), null: false
      add :due_on, :date, null: false
      add :note, :text, null: false
      add :status, :string, null: false, default: "pending"
      add :completed_at, :utc_datetime
      add :notified_at, :utc_datetime
      add :escalated_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:bring_ups, [:assignee_id, :status, :due_on])
    create index(:bring_ups, [:matter_id])

    create constraint(:bring_ups, :bring_ups_status_check,
             check: "status IN ('pending', 'done', 'snoozed', 'cancelled')"
           )

    create table(:notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :matter_id, references(:matters, on_delete: :delete_all)
      add :bring_up_id, references(:bring_ups, on_delete: :delete_all)
      add :type, :string, null: false
      add :title, :string, null: false
      add :body, :text, null: false
      add :read_at, :utc_datetime
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:notifications, [:user_id, :read_at, :inserted_at])
  end
end
