defmodule ZockeloWeb.Live.AuthHooks do
  @moduledoc """
  LiveView on_mount hooks for authentication and tenant scoping.

  Usage in LiveView:
      on_mount {ZockeloWeb.Live.AuthHooks, :require_authenticated}
      on_mount {ZockeloWeb.Live.AuthHooks, :require_tenant_member}
  """
  import Phoenix.LiveView, only: [redirect: 2]
  import Phoenix.Component, only: [assign: 2]

  alias Zockelo.Auth

  # Loads the session without redirecting — unauthenticated sockets get current_session: nil.
  def on_mount(:load_session, _params, session, socket) do
    {:cont, mount_session(socket, session)}
  end

  def on_mount(:require_authenticated, params, session, socket) do
    socket = mount_session(socket, session)

    if socket.assigns[:current_session] do
      {:cont, socket}
    else
      tenant_slug = params["tenant_slug"]
      login_path = if tenant_slug, do: "/#{tenant_slug}/login", else: "/login"
      {:halt, redirect(socket, to: login_path)}
    end
  end

  def on_mount(:require_tenant_member, params, session, socket) do
    socket = mount_session(socket, session)

    with %{current_session: s} when not is_nil(s) <- socket.assigns,
         %{"tenant_slug" => slug} <- params,
         {:ok, tenant, profile} <- resolve_tenant_member(slug, s.player_id) do
      {:cont,
       socket
       |> assign(current_tenant: tenant, current_user: profile)}
    else
      _ ->
        tenant_slug = params["tenant_slug"]
        login_path = if tenant_slug, do: "/#{tenant_slug}/login", else: "/login"
        {:halt, redirect(socket, to: login_path)}
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp mount_session(socket, session) do
    case Map.get(session, "session_id") do
      nil ->
        assign(socket, current_session: nil)

      session_id ->
        case Auth.validate_session(session_id) do
          {:ok, db_session} -> assign(socket, current_session: db_session)
          {:error, _} -> assign(socket, current_session: nil)
        end
    end
  end

  defp resolve_tenant_member(slug, player_id) do
    import Ecto.Query

    alias Zockelo.Repo
    alias Zockelo.Projections.{TenantRead, PlayerProfile}

    with tenant when not is_nil(tenant) <- Repo.get_by(TenantRead, slug: slug),
         profile when not is_nil(profile) <-
           Repo.one(
             from p in PlayerProfile,
               where: p.player_id == ^player_id and p.tenant_id == ^tenant.id
           ) do
      {:ok, tenant, profile}
    else
      _ -> {:error, :not_found}
    end
  end
end
