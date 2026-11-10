defmodule Sla.Repo.Migrations.CreateBillingAndAccounts do
  use Ecto.Migration

  def change do
    create table(:fee_agreements) do
      add :matter_id, references(:matters, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :amount, :decimal, precision: 18, scale: 2
      add :currency, :string, null: false, default: "KES"
      add :terms, :text
      timestamps(type: :utc_datetime)
    end

    create unique_index(:fee_agreements, [:matter_id])

    create table(:billing_rates) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :role, :string
      add :amount, :decimal, precision: 18, scale: 2, null: false
      add :currency, :string, null: false, default: "KES"
      timestamps(type: :utc_datetime)
    end

    create constraint(:billing_rates, :rate_owner_required,
             check: "user_id IS NOT NULL OR role IS NOT NULL"
           )

    create table(:invoices) do
      add :client_id, references(:clients, on_delete: :restrict), null: false
      add :matter_id, references(:matters, on_delete: :restrict), null: false
      add :number, :string
      add :type, :string, null: false, default: "tax"
      add :status, :string, null: false, default: "draft"
      add :currency, :string, null: false, default: "KES"
      add :issued_on, :date
      add :due_on, :date
      add :subtotal, :decimal, precision: 18, scale: 2, null: false, default: 0
      add :vat, :decimal, precision: 18, scale: 2, null: false, default: 0
      add :total, :decimal, precision: 18, scale: 2, null: false, default: 0
      add :approved_by_id, references(:users, on_delete: :nilify_all)
      add :approved_at, :utc_datetime
      add :issued_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:invoices, [:number], where: "number IS NOT NULL")
    create index(:invoices, [:client_id, :status])

    create table(:invoice_lines) do
      add :invoice_id, references(:invoices, on_delete: :delete_all), null: false
      add :description, :text, null: false
      add :quantity, :decimal, precision: 12, scale: 2, null: false, default: 1
      add :unit_price, :decimal, precision: 18, scale: 2, null: false
      add :vat_rate, :decimal, precision: 5, scale: 2, null: false, default: 16
      add :source, :string, null: false
      add :source_id, :bigint
      timestamps(type: :utc_datetime)
    end

    create table(:time_entries) do
      add :matter_id, references(:matters, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :restrict), null: false
      add :date, :date, null: false
      add :minutes, :integer, null: false
      add :rate, :decimal, precision: 18, scale: 2, null: false
      add :description, :text, null: false
      add :billable, :boolean, null: false, default: true
      add :started_at, :utc_datetime
      add :invoice_line_id, references(:invoice_lines, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create table(:disbursements) do
      add :matter_id, references(:matters, on_delete: :delete_all), null: false
      add :date, :date, null: false
      add :type, :string, null: false
      add :description, :text, null: false
      add :amount, :decimal, precision: 18, scale: 2, null: false
      add :vat_applicable, :boolean, null: false, default: false
      add :rebillable, :boolean, null: false, default: true
      add :receipt_document_id, references(:documents, on_delete: :nilify_all)
      add :invoice_line_id, references(:invoice_lines, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create table(:payments) do
      add :client_id, references(:clients, on_delete: :restrict), null: false
      add :method, :string, null: false
      add :reference, :string, null: false
      add :amount, :decimal, precision: 18, scale: 2, null: false
      add :currency, :string, null: false, default: "KES"
      add :received_on, :date, null: false
      add :withholding_tax, :decimal, precision: 18, scale: 2, null: false, default: 0
      add :receipt_number, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:payments, [:receipt_number], where: "receipt_number IS NOT NULL")

    create table(:payment_allocations) do
      add :payment_id, references(:payments, on_delete: :delete_all), null: false
      add :invoice_id, references(:invoices, on_delete: :restrict), null: false
      add :amount, :decimal, precision: 18, scale: 2, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:payment_allocations, [:payment_id, :invoice_id])

    create table(:document_sequences, primary_key: false) do
      add :type, :string, primary_key: true
      add :year, :integer, primary_key: true
      add :value, :integer, null: false, default: 0
    end

    create table(:ledger_entries) do
      add :matter_id, references(:matters, on_delete: :restrict), null: false
      add :account, :string, null: false
      add :direction, :string, null: false
      add :amount, :decimal, precision: 18, scale: 2, null: false
      add :currency, :string, null: false, default: "KES"
      add :description, :text, null: false
      add :reference, :string
      add :transfer_group, :uuid
      add :approved_by_id, references(:users, on_delete: :restrict)
      add :posted_by_id, references(:users, on_delete: :restrict), null: false
      add :posted_on, :date, null: false
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:ledger_entries, [:matter_id, :account, :posted_on])

    create table(:bank_reconciliations) do
      add :account, :string, null: false
      add :transaction_date, :date, null: false
      add :description, :text, null: false
      add :reference, :string
      add :amount, :decimal, precision: 18, scale: 2, null: false
      add :matched_ledger_entry_id, references(:ledger_entries, on_delete: :nilify_all)
      add :imported_by_id, references(:users, on_delete: :restrict), null: false
      timestamps(type: :utc_datetime)
    end

    create table(:audit_logs) do
      add :actor_id, references(:users, on_delete: :nilify_all)
      add :action, :string, null: false
      add :entity_type, :string, null: false
      add :entity_id, :string
      add :metadata, :map, null: false, default: %{}
      add :occurred_at, :utc_datetime, null: false
    end

    create index(:audit_logs, [:entity_type, :entity_id])
  end
end
