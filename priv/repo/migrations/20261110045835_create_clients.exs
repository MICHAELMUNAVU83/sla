defmodule Sla.Repo.Migrations.CreateClients do
  use Ecto.Migration

  def change do
    create table(:clients) do
      add :type, :string, null: false
      add :name, :string, null: false
      add :kra_pin, :string
      add :identification_number, :string
      add :email, :string
      add :phone, :string
      add :address, :text
      add :kyc_status, :string, null: false, default: "pending"
      timestamps(type: :utc_datetime)
    end

    create constraint(:clients, :clients_type_check, check: "type IN ('individual', 'company')")

    create constraint(:clients, :clients_kyc_status_check,
             check: "kyc_status IN ('pending', 'in_review', 'verified', 'rejected')"
           )

    create index(:clients, [:type])
    create index(:clients, [:name])
    create unique_index(:clients, [:kra_pin], where: "kra_pin IS NOT NULL")

    create table(:client_contacts) do
      add :client_id, references(:clients, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :title, :string
      add :email, :string
      add :phone, :string
      add :primary, :boolean, null: false, default: false
      timestamps(type: :utc_datetime)
    end

    create index(:client_contacts, [:client_id])
  end
end
