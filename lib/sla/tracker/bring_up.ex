defmodule Sla.Tracker.BringUp do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending done snoozed cancelled)

  schema "bring_ups" do
    field :due_on, :date
    field :note, :string
    field :status, :string, default: "pending"
    field :completed_at, :utc_datetime
    field :notified_at, :utc_datetime
    field :escalated_at, :utc_datetime
    belongs_to :matter, Sla.Matters.Matter
    belongs_to :activity, Sla.Tracker.FileActivity
    belongs_to :assignee, Sla.Accounts.User
    belongs_to :created_by, Sla.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(bring_up, attrs) do
    bring_up
    |> cast(attrs, [
      :matter_id,
      :activity_id,
      :assignee_id,
      :created_by_id,
      :due_on,
      :note,
      :status,
      :completed_at,
      :notified_at,
      :escalated_at
    ])
    |> validate_required([:matter_id, :assignee_id, :created_by_id, :due_on, :note, :status])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:matter_id)
    |> foreign_key_constraint(:activity_id)
    |> foreign_key_constraint(:assignee_id)
    |> foreign_key_constraint(:created_by_id)
  end
end
