defmodule Zockelo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ZockeloWeb.Telemetry,
      Zockelo.Vault,
      Zockelo.Repo,
      {DNSCluster, query: Application.get_env(:zockelo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Zockelo.PubSub},
      # CommandedApp supervises EventStore internally via the adapter
      Zockelo.CommandedApp,
      # Event handlers
      Zockelo.Workers.TenantDeletionScheduler,
      # Background jobs
      {Oban, Application.fetch_env!(:zockelo, Oban)},
      # Start to serve requests, typically the last entry
      ZockeloWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Zockelo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ZockeloWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
