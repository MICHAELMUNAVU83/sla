defmodule Sla.Practice.DeadlineRule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "deadline_rules" do
    field :name, :string
    field :trigger_event_type, :string
    field :days, :integer
    field :business_days, :boolean, default: false
    field :result_event_type, :string, default: "deadline"
    field :active, :boolean, default: true
    timestamps(type: :utc_datetime)
  end

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [
      :name,
      :trigger_event_type,
      :days,
      :business_days,
      :result_event_type,
      :active
    ])
    |> validate_required([:name, :trigger_event_type, :days, :result_event_type])
    |> validate_number(:days, greater_than: 0)
    |> unique_constraint(:name)
  end
end
