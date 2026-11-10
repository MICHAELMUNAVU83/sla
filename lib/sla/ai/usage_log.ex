defmodule Sla.AI.UsageLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ai_usage_logs" do
    field :operation, :string
    field :model, :string
    field :input_tokens, :integer, default: 0
    field :output_tokens, :integer, default: 0
    field :duration_ms, :integer, default: 0
    field :success, :boolean
    field :error, :string
    belongs_to :user, Sla.Accounts.User
    belongs_to :matter, Sla.Matters.Matter
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :operation,
      :model,
      :input_tokens,
      :output_tokens,
      :duration_ms,
      :success,
      :error,
      :user_id,
      :matter_id
    ])
    |> validate_required([:operation, :model, :success])
  end
end
