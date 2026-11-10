defmodule Sla.Matters.Matter do
  use Ecto.Schema
  import Ecto.Changeset

  @practice_areas ~w(real_estate banking_finance dispute_resolution corporate_commercial)
  @statuses ~w(open dormant closed archived)

  schema "matters" do
    field :file_number, :string
    field :title, :string
    field :practice_area, :string
    field :status, :string, default: "open"
    field :opened_on, :date
    field :closed_on, :date
    field :court, :string
    field :case_number, :string
    field :last_activity_at, :utc_datetime
    field :last_activity_summary, :string
    field :dormant_alerted_at, :utc_datetime
    field :retention_until, :date
    field :archived_at, :utc_datetime
    belongs_to :client, Sla.Clients.Client
    belongs_to :responsible_advocate, Sla.Accounts.User
    many_to_many :members, Sla.Accounts.User, join_through: "matter_members", on_replace: :delete
    has_many :parties, Sla.Matters.MatterParty
    has_many :calendar_events, Sla.Practice.CalendarEvent
    has_many :tasks, Sla.Practice.MatterTask
    timestamps(type: :utc_datetime)
  end

  def practice_areas, do: @practice_areas
  def statuses, do: @statuses

  def changeset(matter, attrs) do
    matter
    |> cast(attrs, [
      :client_id,
      :title,
      :practice_area,
      :status,
      :responsible_advocate_id,
      :opened_on,
      :closed_on,
      :court,
      :case_number,
      :retention_until
    ])
    |> validate_required([:client_id, :title, :practice_area, :status, :opened_on])
    |> validate_inclusion(:practice_area, @practice_areas)
    |> validate_inclusion(:status, @statuses)
    |> validate_closed_date()
    |> foreign_key_constraint(:client_id)
    |> foreign_key_constraint(:responsible_advocate_id)
  end

  defp validate_closed_date(changeset) do
    opened_on = get_field(changeset, :opened_on)
    closed_on = get_field(changeset, :closed_on)

    if opened_on && closed_on && Date.before?(closed_on, opened_on) do
      add_error(changeset, :closed_on, "cannot be before the opened date")
    else
      changeset
    end
  end
end
