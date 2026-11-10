defmodule Sla.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:document_categories) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :practice_area, :string
      add :position, :integer, null: false, default: 0
      add :active, :boolean, null: false, default: true
      timestamps(type: :utc_datetime)
    end

    create unique_index(:document_categories, [:slug],
             where: "practice_area IS NULL",
             name: :document_categories_global_slug_index
           )

    create unique_index(:document_categories, [:practice_area, :slug],
             where: "practice_area IS NOT NULL",
             name: :document_categories_area_slug_index
           )

    execute """
            INSERT INTO document_categories (name, slug, position, inserted_at, updated_at) VALUES
              ('Pleadings', 'pleadings', 10, NOW(), NOW()),
              ('Correspondence', 'correspondence', 20, NOW(), NOW()),
              ('Agreements', 'agreements', 30, NOW(), NOW()),
              ('Court Orders', 'court-orders', 40, NOW(), NOW()),
              ('Title Documents', 'title-documents', 50, NOW(), NOW()),
              ('KYC', 'kyc', 60, NOW(), NOW()),
              ('Invoices & Receipts', 'invoices-receipts', 70, NOW(), NOW()),
              ('Evidence', 'evidence', 80, NOW(), NOW()),
              ('Internal Notes', 'internal-notes', 90, NOW(), NOW())
            """,
            "DELETE FROM document_categories WHERE practice_area IS NULL"

    create table(:documents) do
      add :client_id, references(:clients, on_delete: :restrict), null: false
      add :matter_id, references(:matters, on_delete: :delete_all)
      add :category_id, references(:document_categories, on_delete: :restrict), null: false
      add :title, :string, null: false
      add :tags, {:array, :string}, null: false, default: []
      add :extracted_text, :text
      add :uploaded_by_id, references(:users, on_delete: :restrict), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:documents, [:client_id, :matter_id, :category_id])
    create index(:documents, [:uploaded_by_id])

    create table(:document_versions) do
      add :document_id, references(:documents, on_delete: :delete_all), null: false
      add :storage_key, :string, null: false
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :size, :bigint, null: false
      add :checksum, :string, null: false
      add :version_no, :integer, null: false
      add :uploaded_by_id, references(:users, on_delete: :restrict), null: false
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:document_versions, [:document_id, :version_no])
    create unique_index(:document_versions, [:storage_key])

    alter table(:documents) do
      add :current_version_id, references(:document_versions, on_delete: :nilify_all)
    end

    create index(:documents, [:current_version_id])

    execute "ALTER TABLE documents ADD COLUMN search_vector tsvector",
            "ALTER TABLE documents DROP COLUMN search_vector"

    execute """
            CREATE FUNCTION documents_search_vector_update() RETURNS trigger AS $$
            BEGIN
              NEW.search_vector := to_tsvector('english', coalesce(NEW.title, '') || ' ' || coalesce(array_to_string(NEW.tags, ' '), '') || ' ' || coalesce(NEW.extracted_text, ''));
              RETURN NEW;
            END
            $$ LANGUAGE plpgsql;
            """,
            "DROP FUNCTION IF EXISTS documents_search_vector_update()"

    execute """
            CREATE TRIGGER documents_search_vector_trigger
            BEFORE INSERT OR UPDATE OF title, tags, extracted_text ON documents
            FOR EACH ROW EXECUTE FUNCTION documents_search_vector_update();
            """,
            "DROP TRIGGER IF EXISTS documents_search_vector_trigger ON documents"

    execute "CREATE INDEX documents_search_vector_index ON documents USING GIN (search_vector)",
            "DROP INDEX documents_search_vector_index"
  end
end
