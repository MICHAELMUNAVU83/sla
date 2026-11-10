defmodule Sla.Tracker.FileActivity do
  use Ecto.Schema
  import Ecto.Changeset

  @action_types ~w(email_sent email_received call meeting filing court_attendance letter document_received note other)

  schema "file_activities" do
    field :action_type, :string
    field :note, :string
    field :occurred_at, :utc_datetime
    field :document_id, :integer
    field :email_ref, :string
    belongs_to :matter, Sla.Matters.Matter
    belongs_to :user, Sla.Accounts.User
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def action_types, do: @action_types

  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [
      :matter_id,
      :user_id,
      :action_type,
      :note,
      :occurred_at,
      :document_id,
      :email_ref
    ])
    |> validate_required([:matter_id, :user_id, :action_type, :note, :occurred_at])
    |> validate_inclusion(:action_type, @action_types)
    |> validate_length(:note, max: 2_000)
    |> foreign_key_constraint(:matter_id)
    |> foreign_key_constraint(:user_id)
  end
end
