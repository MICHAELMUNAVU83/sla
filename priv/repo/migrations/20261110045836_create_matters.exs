defmodule Sla.Repo.Migrations.CreateMatters do
  use Ecto.Migration

  def change do
    create table(:matter_sequences, primary_key: false) do
      add :practice_area, :string, primary_key: true
      add :year, :integer, primary_key: true
      add :last_number, :integer, null: false, default: 0
    end

    create table(:matters) do
      add :client_id, references(:clients, on_delete: :restrict), null: false
      add :file_number, :string, null: false
      add :title, :string, null: false
      add :practice_area, :string, null: false
      add :status, :string, null: false, default: "open"
      add :responsible_advocate_id, references(:users, on_delete: :nilify_all)
      add :opened_on, :date, null: false
      add :closed_on, :date
      add :court, :string
      add :case_number, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:matters, [:file_number])
    create index(:matters, [:client_id])
    create index(:matters, [:responsible_advocate_id])
    create index(:matters, [:status, :practice_area])

    create constraint(:matters, :matters_status_check,
             check: "status IN ('open', 'dormant', 'closed', 'archived')"
           )

    create constraint(:matters, :matters_practice_area_check,
             check:
               "practice_area IN ('real_estate', 'banking_finance', 'dispute_resolution', 'corporate_commercial')"
           )

    create table(:matter_members, primary_key: false) do
      add :matter_id, references(:matters, on_delete: :delete_all), primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), primary_key: true
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:matter_members, [:user_id])

    create table(:matter_parties) do
      add :matter_id, references(:matters, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :name, :string, null: false
      add :email, :string
      add :phone, :string
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create index(:matter_parties, [:matter_id])

    create constraint(:matter_parties, :matter_parties_type_check,
             check: "type IN ('opposing_party', 'opposing_counsel', 'court', 'other')"
           )
  end
end
