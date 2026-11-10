defmodule Sla.Repo.Migrations.AddFoundationToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :name, :string, null: false, default: ""
      add :role, :string, null: false, default: "associate"
      add :active, :boolean, null: false, default: true
      add :totp_secret, :binary
      add :totp_enabled_at, :utc_datetime
    end

    create constraint(:users, :users_role_check,
             check: "role IN ('partner', 'advocate', 'associate', 'clerk', 'accounts', 'admin')"
           )
  end
end
