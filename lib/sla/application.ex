defmodule Sla.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SlaWeb.Telemetry,
      Sla.Repo,
      {DNSCluster, query: Application.get_env(:sla, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Sla.PubSub},
      {Oban, Application.fetch_env!(:sla, Oban)},
      # Start a worker by calling: Sla.Worker.start_link(arg)
      # {Sla.Worker, arg},
      # Start to serve requests, typically the last entry
      SlaWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sla.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SlaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
