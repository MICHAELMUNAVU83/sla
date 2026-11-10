defmodule Sla.Repo do
  use Ecto.Repo,
    otp_app: :sla,
    adapter: Ecto.Adapters.Postgres
end
