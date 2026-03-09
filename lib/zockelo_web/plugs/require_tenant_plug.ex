defmodule ZockeloWeb.Plugs.RequireTenantPlug do
  @moduledoc """
  Resolves the tenant from the URL slug and verifies the current player is
  a member of that tenant. Assigns `:current_tenant` and `:current_user`.
  Returns 404 if the tenant doesn't exist or the player isn't a member.
  Super-admins bypass the membership check (future: checked via super_admins table).
  """
  import Plug.Conn
  import Ecto.Query

  alias Zockelo.Repo
  alias Zockelo.Projections.{TenantRead, PlayerProfile}

  def init(opts), do: opts

  def call(conn, _opts) do
    tenant_slug = conn.params["tenant_slug"]
    session = conn.assigns[:current_session]

    with {:ok, tenant} <- fetch_tenant(tenant_slug),
         {:ok, profile} <- fetch_profile(session.player_id, tenant.id) do
      conn
      |> assign(:current_tenant, tenant)
      |> assign(:current_user, profile)
    else
      _ -> not_found(conn)
    end
  end

  defp fetch_tenant(nil), do: {:error, :no_slug}

  defp fetch_tenant(slug) do
    case Repo.get_by(TenantRead, slug: slug) do
      nil -> {:error, :not_found}
      tenant -> {:ok, tenant}
    end
  end

  defp fetch_profile(player_id, tenant_id) do
    case Repo.one(
           from p in PlayerProfile,
             where: p.player_id == ^player_id and p.tenant_id == ^tenant_id
         ) do
      nil -> {:error, :not_member}
      profile -> {:ok, profile}
    end
  end

  defp not_found(conn) do
    conn
    |> send_resp(404, "")
    |> halt()
  end
end
