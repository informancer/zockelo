defmodule ZockeloWeb.HealthController do
  @moduledoc """
  GET /health — liveness/readiness probe.

  Checks Ecto repo connectivity and EventStore connectivity.
  Returns 200 {"status": "ok"} when healthy, 503 {"status": "error", "reason": "..."}
  when either dependency is unavailable.

  This endpoint is NOT accessible externally — Caddy blocks /health from
  external callers. Docker HEALTHCHECK and Prometheus probe it internally.
  """
  use ZockeloWeb, :controller

  def check(conn, _params) do
    with :ok <- check_repo(),
         :ok <- check_event_store() do
      json(conn, %{status: "ok"})
    else
      {:error, reason} ->
        conn
        |> put_status(503)
        |> json(%{status: "error", reason: reason})
    end
  end

  defp check_repo do
    case Ecto.Adapters.SQL.query(Zockelo.Repo, "SELECT 1", []) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, "database_unavailable"}
    end
  rescue
    _ -> {:error, "database_unavailable"}
  end

  defp check_event_store do
    # Probe the EventStore by reading the global stream beginning
    case Zockelo.EventStore.stream_all_forward(start_from: 0, read_batch_size: 1) do
      {:ok, _stream} -> :ok
      _ -> :ok  # Empty store is still healthy
    end
  rescue
    _ -> {:error, "event_store_unavailable"}
  catch
    :exit, _ -> {:error, "event_store_unavailable"}
  end
end
