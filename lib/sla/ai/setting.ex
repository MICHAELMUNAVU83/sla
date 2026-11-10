defmodule Sla.AI.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_settings" do
    field :enabled, :boolean, default: false
    field :provider, :string, default: "claude"
    field :model, :string, default: "claude-sonnet-4-5"
    belongs_to :updated_by, Sla.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:enabled, :provider, :model, :updated_by_id])
    |> validate_required([:provider, :model])
    |> validate_inclusion(:provider, ["claude"])
  end
end
