defmodule Sla.Practice.WorkflowTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workflow_templates" do
    field :name, :string
    field :practice_area, :string
    field :matter_type, :string
    field :description, :string
    field :active, :boolean, default: true
    has_many :steps, Sla.Practice.WorkflowStep, preload_order: [asc: :position]
    timestamps(type: :utc_datetime)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name, :practice_area, :matter_type, :description, :active])
    |> validate_required([:name, :practice_area, :matter_type])
    |> unique_constraint(:name)
  end
end
