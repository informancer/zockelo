defmodule Zockelo.Authorization do
  @moduledoc """
  Role-based authorization helper.

  Roles (stored in player_profiles.role):
    - "super_admin" — system-wide access
    - "tenant_admin" — admin within their tenant
    - "player"       — regular tenant member

  Actions:
    - :view       — any authenticated tenant member
    - :log_game   — any authenticated tenant member
    - :admin      — tenant_admin (own tenant) or super_admin
    - :super_admin — super_admin only
  """

  alias Zockelo.Projections.PlayerProfile

  @doc """
  Returns `:ok` or `{:error, :unauthenticated | :forbidden}`.
  """
  def authorize(nil, _action, _opts), do: {:error, :unauthenticated}

  def authorize(%PlayerProfile{role: "super_admin"}, _action, _opts), do: :ok

  def authorize(%PlayerProfile{}, :super_admin, _opts), do: {:error, :forbidden}

  def authorize(%PlayerProfile{role: "tenant_admin", tenant_id: tid}, :admin, tenant_id)
      when tid == tenant_id,
      do: :ok

  def authorize(%PlayerProfile{}, :admin, _tenant_id), do: {:error, :forbidden}

  def authorize(%PlayerProfile{}, _action, _opts), do: :ok
end
