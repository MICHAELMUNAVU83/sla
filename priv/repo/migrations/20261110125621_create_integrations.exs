defmodule Sla.Repo.Migrations.CreateIntegrations do
  use Ecto.Migration

  def change do
    create table(:integration_connections) do
      add :provider, :string, null: false
      add :status, :string, null: false, default: "disconnected"
      add :settings, :map, null: false, default: %{}
      add :credentials, :binary
      add :last_synced_at, :utc_datetime
      add :last_error, :text
      add :created_by_id, references(:users, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create unique_index(:integration_connections, [:provider])

    create table(:integration_events) do
      add :provider, :string, null: false
      add :external_id, :string, null: false
      add :kind, :string, null: false
      add :status, :string, null: false, default: "received"
      add :payload, :map, null: false, default: %{}
      add :result, :map, null: false, default: %{}
      add :error, :text
      add :processed_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:integration_events, [:provider, :external_id])
    create index(:integration_events, [:provider, :status])

    create table(:portal_accounts) do
      add :client_id, references(:clients, on_delete: :delete_all), null: false
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :utc_datetime
      add :last_login_at, :utc_datetime
      add :active, :boolean, null: false, default: true
      timestamps(type: :utc_datetime)
    end

    create unique_index(:portal_accounts, [:email])

    create table(:portal_messages) do
      add :client_id, references(:clients, on_delete: :delete_all), null: false
      add :matter_id, references(:matters, on_delete: :delete_all), null: false
      add :portal_account_id, references(:portal_accounts, on_delete: :nilify_all)
      add :user_id, references(:users, on_delete: :nilify_all)
      add :body, :text, null: false
      add :from_client, :boolean, null: false
      add :read_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:portal_messages, [:matter_id, :inserted_at])

    create table(:signature_requests) do
      add :document_id, references(:documents, on_delete: :restrict), null: false
      add :matter_id, references(:matters, on_delete: :delete_all), null: false
      add :requested_by_id, references(:users, on_delete: :nilify_all)
      add :provider, :string, null: false
      add :external_id, :string
      add :signer_name, :string, null: false
      add :signer_email, :citext, null: false
      add :status, :string, null: false, default: "draft"
      add :sent_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :audit_data, :map, null: false, default: %{}
      timestamps(type: :utc_datetime)
    end

    create unique_index(:signature_requests, [:provider, :external_id],
             where: "external_id IS NOT NULL"
           )

    alter table(:invoices) do
      add :etims_control_number, :string
      add :etims_qr_data, :text
      add :etims_status, :string
      add :etims_submitted_at, :utc_datetime
    end

    alter table(:payments) do
      add :external_provider, :string
      add :external_id, :string
      add :phone, :string
    end

    create unique_index(:payments, [:external_provider, :external_id],
             where: "external_id IS NOT NULL"
           )
  end
end
