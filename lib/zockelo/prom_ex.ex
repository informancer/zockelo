defmodule Zockelo.PromEx do
  @moduledoc """
  PromEx configuration for Prometheus metrics export.

  Metrics are served at GET /metrics (internal only — Caddy should block
  this path from external traffic; Prometheus scrapes it container-to-container).
  """
  use PromEx, otp_app: :zockelo

  @impl true
  def plugins do
    [
      PromEx.Plugins.Application,
      PromEx.Plugins.Beam,
      {PromEx.Plugins.Phoenix, router: ZockeloWeb.Router, endpoint: ZockeloWeb.Endpoint},
      PromEx.Plugins.PhoenixLiveView,
      {PromEx.Plugins.Ecto, repos: [Zockelo.Repo]},
      {PromEx.Plugins.Oban, queues: [:notifications, :scheduled, :critical]}
    ]
  end

  @impl true
  def dashboard_assigns do
    [datasource_id: "prometheus"]
  end

  @impl true
  def dashboards do
    []
  end
end
