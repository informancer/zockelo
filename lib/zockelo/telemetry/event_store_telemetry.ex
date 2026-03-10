defmodule Zockelo.Telemetry.EventStoreTelemetry do
  @moduledoc """
  Attaches Telemetry handlers for EventStore read/write latency.

  Emits:
    [:zockelo, :event_store, :append, :start | :stop | :exception]
    [:zockelo, :event_store, :read, :start | :stop | :exception]
  """

  require Logger

  def setup do
    :telemetry.attach_many(
      "zockelo-eventstore-telemetry",
      [
        [:eventstore, :write_events, :start],
        [:eventstore, :write_events, :stop],
        [:eventstore, :write_events, :exception],
        [:eventstore, :read_events, :start],
        [:eventstore, :read_events, :stop],
        [:eventstore, :read_events, :exception]
      ],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event([:eventstore, :write_events, :stop], measurements, metadata, _config) do
    :telemetry.execute(
      [:zockelo, :event_store, :append, :stop],
      %{duration: measurements[:duration]},
      %{stream: metadata[:stream_uuid]}
    )
  end

  def handle_event([:eventstore, :read_events, :stop], measurements, metadata, _config) do
    :telemetry.execute(
      [:zockelo, :event_store, :read, :stop],
      %{duration: measurements[:duration]},
      %{stream: metadata[:stream_uuid]}
    )
  end

  def handle_event([:eventstore, _, :exception], _measurements, metadata, _config) do
    Logger.warning("EventStore operation failed",
      kind: metadata[:kind],
      reason: inspect(metadata[:reason])
    )
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok
end
