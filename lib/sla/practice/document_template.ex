defmodule Sla.Practice.DocumentTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "document_templates" do
    field :name, :string
    field :format, :string, default: "html"
    field :body, :string
    field :active, :boolean, default: true
    timestamps(type: :utc_datetime)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name, :format, :body, :active])
    |> validate_required([:name, :format, :body])
    |> validate_inclusion(:format, ~w(html docx))
    |> unique_constraint(:name)
  end
end
