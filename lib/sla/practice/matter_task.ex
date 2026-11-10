defmodule Sla.Practice.MatterTask do
  use Ecto.Schema
  import Ecto.Changeset

  schema "matter_tasks" do
    field :title, :string
    field :description, :string
    field :due_on, :date
    field :status, :string, default: "pending"
    field :position, :integer, default: 0
    field :completed_at, :utc_datetime
    belongs_to :matter, Sla.Matters.Matter
    belongs_to :assignee, Sla.Accounts.User
    belongs_to :created_by, Sla.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [:assignee_id, :title, :description, :due_on, :status, :position])
    |> validate_required([:title, :status])
    |> validate_inclusion(:status, ~w(pending in_progress completed cancelled))
  end
end
