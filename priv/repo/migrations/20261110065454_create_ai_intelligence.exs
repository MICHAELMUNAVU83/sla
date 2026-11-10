defmodule Sla.Repo.Migrations.CreateAiIntelligence do
  use Ecto.Migration

  def change do
    create table(:ai_settings) do
      add :enabled, :boolean, null: false, default: false
      add :provider, :string, null: false, default: "claude"
      add :model, :string, null: false, default: "claude-sonnet-4-5"
      add :updated_by_id, references(:users, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create table(:ai_outputs) do
      add :kind, :string, null: false
      add :status, :string, null: false, default: "pending_review"
      add :content, :map, null: false, default: %{}
      add :prompt_version, :string, null: false, default: "v1"
      add :matter_id, references(:matters, on_delete: :delete_all)
      add :document_id, references(:documents, on_delete: :delete_all)
      add :requested_by_id, references(:users, on_delete: :nilify_all)
      add :reviewed_by_id, references(:users, on_delete: :nilify_all)
      add :reviewed_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:ai_outputs, [:matter_id, :kind])
    create index(:ai_outputs, [:document_id, :kind])
    create index(:ai_outputs, [:status])

    create table(:ai_usage_logs) do
      add :operation, :string, null: false
      add :model, :string, null: false
      add :input_tokens, :integer, null: false, default: 0
      add :output_tokens, :integer, null: false, default: 0
      add :duration_ms, :integer, null: false, default: 0
      add :success, :boolean, null: false
      add :error, :string
      add :user_id, references(:users, on_delete: :nilify_all)
      add :matter_id, references(:matters, on_delete: :nilify_all)
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:ai_usage_logs, [:inserted_at])
    create index(:ai_usage_logs, [:matter_id])

    alter table(:documents) do
      add :ocr_status, :string, null: false, default: "not_requested"
      add :extracted_data, :map, null: false, default: %{}
      add :embedding, {:array, :float}
    end
  end
end
