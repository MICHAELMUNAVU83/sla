defmodule Sla.Practice.CalendarEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @types ~w(hearing mention deadline meeting filing other)
  schema "calendar_events" do
    field :title, :string
    field :event_type, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :all_day, :boolean, default: false
    field :court, :string
    field :location, :string
    field :notes, :string
    field :external_provider, :string
    field :external_id, :string
    belongs_to :matter, Sla.Matters.Matter
    belongs_to :created_by, Sla.Accounts.User
    belongs_to :assigned_to, Sla.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def types, do: @types

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :matter_id,
      :assigned_to_id,
      :title,
      :event_type,
      :starts_at,
      :ends_at,
      :all_day,
      :court,
      :location,
      :notes
    ])
    |> validate_required([:title, :event_type, :starts_at])
    |> validate_inclusion(:event_type, @types)
    |> validate_change(:ends_at, fn _, finish ->
      start = get_field(event |> changeset_start(attrs), :starts_at)

      if start && DateTime.before?(finish, start),
        do: [ends_at: "cannot be before start"],
        else: []
    end)
  end

  defp changeset_start(event, attrs), do: cast(event, attrs, [:starts_at])
end
