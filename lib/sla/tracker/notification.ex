defmodule Sla.Tracker.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :type, :string
    field :title, :string
    field :body, :string
    field :read_at, :utc_datetime
    belongs_to :user, Sla.Accounts.User
    belongs_to :matter, Sla.Matters.Matter
    belongs_to :bring_up, Sla.Tracker.BringUp
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :matter_id, :bring_up_id, :type, :title, :body, :read_at])
    |> validate_required([:user_id, :type, :title, :body])
  end
end
