defmodule Sla.Documents.Category do
  use Ecto.Schema
  import Ecto.Changeset

  schema "document_categories" do
    field :name, :string
    field :slug, :string
    field :practice_area, :string
    field :position, :integer, default: 0
    field :active, :boolean, default: true
    timestamps(type: :utc_datetime)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug, :practice_area, :position, :active])
    |> validate_required([:name, :slug])
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/)
    |> unique_constraint(:slug, name: :document_categories_global_slug_index)
    |> unique_constraint([:practice_area, :slug], name: :document_categories_area_slug_index)
  end
end
