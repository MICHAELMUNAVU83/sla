defmodule Sla.Repo.Migrations.CreatePracticeManagement do
  use Ecto.Migration

  def change do
    create table(:client_intakes) do
      add :client_id, references(:clients, on_delete: :nilify_all)
      add :submitted_by_id, references(:users, on_delete: :nilify_all)
      add :client_type, :string, null: false
      add :name, :string, null: false
      add :email, :string
      add :phone, :string
      add :identification_number, :string
      add :kra_pin, :string
      add :address, :text
      add :matter_summary, :text, null: false
      add :status, :string, null: false, default: "submitted"
      add :consent_given, :boolean, null: false, default: false
      timestamps(type: :utc_datetime)
    end

    create table(:conflict_checks) do
      add :matter_id, references(:matters, on_delete: :delete_all)
      add :client_intake_id, references(:client_intakes, on_delete: :delete_all)
      add :performed_by_id, references(:users, on_delete: :restrict), null: false
      add :search_terms, {:array, :string}, null: false, default: []
      add :matches, :map, null: false, default: %{}
      add :result, :string, null: false
      add :notes, :text
      add :performed_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:conflict_checks, [:matter_id])
    create index(:conflict_checks, [:client_intake_id])

    create table(:kyc_checks) do
      add :client_id, references(:clients, on_delete: :delete_all), null: false
      add :reviewed_by_id, references(:users, on_delete: :nilify_all)
      add :id_verified, :boolean, null: false, default: false
      add :kra_pin_verified, :boolean, null: false, default: false
      add :cr12_verified, :boolean, null: false, default: false
      add :beneficial_owners_verified, :boolean, null: false, default: false
      add :source_of_funds_verified, :boolean, null: false, default: false
      add :risk_rating, :string, null: false, default: "unrated"
      add :notes, :text
      add :reviewed_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:kyc_checks, [:client_id])

    create table(:calendar_events) do
      add :matter_id, references(:matters, on_delete: :delete_all)
      add :created_by_id, references(:users, on_delete: :restrict), null: false
      add :assigned_to_id, references(:users, on_delete: :nilify_all)
      add :title, :string, null: false
      add :event_type, :string, null: false
      add :starts_at, :utc_datetime, null: false
      add :ends_at, :utc_datetime
      add :all_day, :boolean, null: false, default: false
      add :court, :string
      add :location, :string
      add :notes, :text
      add :external_provider, :string
      add :external_id, :string
      timestamps(type: :utc_datetime)
    end

    create index(:calendar_events, [:starts_at])
    create index(:calendar_events, [:matter_id, :starts_at])

    create table(:deadline_rules) do
      add :name, :string, null: false
      add :trigger_event_type, :string, null: false
      add :days, :integer, null: false
      add :business_days, :boolean, null: false, default: false
      add :result_event_type, :string, null: false, default: "deadline"
      add :active, :boolean, null: false, default: true
      timestamps(type: :utc_datetime)
    end

    create unique_index(:deadline_rules, [:name])

    create table(:matter_tasks) do
      add :matter_id, references(:matters, on_delete: :delete_all), null: false
      add :assignee_id, references(:users, on_delete: :nilify_all)
      add :created_by_id, references(:users, on_delete: :restrict), null: false
      add :title, :string, null: false
      add :description, :text
      add :due_on, :date
      add :status, :string, null: false, default: "pending"
      add :position, :integer, null: false, default: 0
      add :completed_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:matter_tasks, [:matter_id, :status])
    create index(:matter_tasks, [:assignee_id, :due_on])

    create table(:workflow_templates) do
      add :name, :string, null: false
      add :practice_area, :string, null: false
      add :matter_type, :string, null: false
      add :description, :text
      add :active, :boolean, null: false, default: true
      timestamps(type: :utc_datetime)
    end

    create unique_index(:workflow_templates, [:name])

    create table(:workflow_steps) do
      add :workflow_template_id, references(:workflow_templates, on_delete: :delete_all),
        null: false

      add :title, :string, null: false
      add :description, :text
      add :days_from_start, :integer, null: false, default: 0
      add :position, :integer, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:workflow_steps, [:workflow_template_id, :position])

    create table(:document_templates) do
      add :name, :string, null: false
      add :format, :string, null: false, default: "html"
      add :body, :text, null: false
      add :active, :boolean, null: false, default: true
      timestamps(type: :utc_datetime)
    end

    create unique_index(:document_templates, [:name])

    create table(:ethical_walls, primary_key: false) do
      add :matter_id, references(:matters, on_delete: :delete_all), primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), primary_key: true
      add :created_by_id, references(:users, on_delete: :restrict), null: false
      add :reason, :text, null: false
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:ethical_walls, [:user_id])

    create table(:matter_closing_items) do
      add :matter_id, references(:matters, on_delete: :delete_all), null: false
      add :label, :string, null: false
      add :completed, :boolean, null: false, default: false
      add :completed_by_id, references(:users, on_delete: :nilify_all)
      add :completed_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:matter_closing_items, [:matter_id])
    create unique_index(:matter_closing_items, [:matter_id, :label])

    alter table(:matters) do
      add :retention_until, :date
      add :archived_at, :utc_datetime
    end
  end
end
