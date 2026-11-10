defmodule Sla.Repo.Migrations.AddPortalVisibilityToDocuments do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      add :portal_visible, :boolean, null: false, default: false
    end
  end
end
