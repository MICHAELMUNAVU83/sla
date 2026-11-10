defmodule Sla.Practice.WorkflowStep do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workflow_steps" do
    field :title, :string
    field :description, :string
    field :days_from_start, :integer, default: 0
    field :position, :integer
    belongs_to :workflow_template, Sla.Practice.WorkflowTemplate
    timestamps(type: :utc_datetime)
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [:title, :description, :days_from_start, :position])
    |> validate_required([:title, :days_from_start, :position])
    |> validate_number(:days_from_start, greater_than_or_equal_to: 0)
  end
end
