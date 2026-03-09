defmodule Zockelo.Audit do
  @moduledoc """
  Writes entries to the admin audit log for security-sensitive actions.

  Audit log entries are never deleted — even if the actor is later removed.
  Unresolvable actors appear as "[Deleted Admin]" in views.
  """

  alias Zockelo.Repo
  alias Zockelo.Audit.AdminAuditLog

  @doc """
  Records an admin action. Fields:
    - actor_id:    UUID of the player performing the action
    - actor_role:  their role at the time of the action
    - tenant_id:   tenant context (nil for super-admin global actions)
    - action:      atom or string, e.g. :delete_player, :rotate_invite_link
    - target_id:   UUID of the affected entity (optional)
    - target_type: string describing the entity type, e.g. "player", "tenant"
    - metadata:    map of additional context
  """
  def log(attrs) do
    base = %{performed_at: DateTime.utc_now(), metadata: %{}}

    merged =
      attrs
      |> Enum.reduce(base, fn {k, v}, acc -> Map.put(acc, to_atom(k), v) end)
      |> Map.update(:action, nil, &to_string/1)

    AdminAuditLog.changeset(merged)
    |> Repo.insert()
    |> case do
      {:ok, _} -> :ok
      {:error, cs} ->
        require Logger
        Logger.error("Failed to write audit log: #{inspect(cs.errors)}")
        :ok
    end
  end

  defp to_atom(k) when is_atom(k), do: k
  defp to_atom(k), do: String.to_existing_atom(k)
end
