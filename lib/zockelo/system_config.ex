defmodule Zockelo.SystemConfig do
  @moduledoc """
  System-wide configuration stored in the `system_config` table.

  Keys:
    - "tenant_creation_mode" — "direct" | "request_approval" (default: "direct")
    - "audit_log_retention_days" — integer string (default: "730")
  """

  alias Zockelo.Repo
  alias Zockelo.SystemConfig.Entry

  @defaults %{
    "tenant_creation_mode" => "direct",
    "audit_log_retention_days" => "730"
  }

  @doc "Returns the value for `key`, falling back to the built-in default."
  def get(key) do
    case Repo.get(Entry, key) do
      nil -> Map.get(@defaults, key)
      %Entry{value: val} -> val
    end
  end

  @doc "Sets `key` to `value` (upsert)."
  def put(key, value) do
    now = DateTime.utc_now()

    Repo.insert!(
      %Entry{key: key, value: to_string(value)},
      on_conflict: [set: [value: to_string(value), updated_at: now]],
      conflict_target: :key
    )

    :ok
  end

  @doc "Returns all config entries as a map."
  def all do
    stored =
      Repo.all(Entry)
      |> Map.new(fn e -> {e.key, e.value} end)

    Map.merge(@defaults, stored)
  end

  @doc "Returns the default value for `key`."
  def default(key), do: Map.get(@defaults, key)
end
