defmodule Sla.AI.Output do
  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(matter_summary next_action classification extraction document_summary draft time_suggestion collection_insight)
  @statuses ~w(pending_review accepted rejected superseded)
  schema "ai_outputs" do
    field :kind, :string
    field :status, :string, default: "pending_review"
    field :content, :map, default: %{}
    field :prompt_version, :string, default: "v1"
    belongs_to :matter, Sla.Matters.Matter
    belongs_to :document, Sla.Documents.Document
    belongs_to :requested_by, Sla.Accounts.User
    belongs_to :reviewed_by, Sla.Accounts.User
    field :reviewed_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end

  def kinds, do: @kinds

  def changeset(output, attrs) do
    output
    |> cast(attrs, [
      :kind,
      :status,
      :content,
      :prompt_version,
      :matter_id,
      :document_id,
      :requested_by_id,
      :reviewed_by_id,
      :reviewed_at
    ])
    |> validate_required([:kind, :status, :content])
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:matter_id)
    |> foreign_key_constraint(:document_id)
  end
end
