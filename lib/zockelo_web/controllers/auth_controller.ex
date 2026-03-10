defmodule ZockeloWeb.AuthController do
  @moduledoc "Handles magic link verification and session creation."
  use ZockeloWeb, :controller

  require Logger

  alias Zockelo.{Auth, Players, Tenants}

  @doc """
  Verifies a magic link token, creates a session, and redirects to the
  appropriate destination based on the player's activation state.
  """
  def magic(conn, %{"token" => token} = params) do
    return_to = safe_return_to(params["return_to"])

    with {:ok, player_id} <- Auth.verify_magic_link(token),
         profile when not is_nil(profile) <- Players.get_player(player_id),
         tenant when not is_nil(tenant) <- Tenants.get_tenant(profile.tenant_id),
         {:ok, session} <- Auth.create_session(player_id, profile.tenant_id) do
      destination = return_to || post_login_path(profile, tenant)

      Players.record_login(player_id)

      Logger.info("auth.login",
        player_id: player_id,
        tenant_id: profile.tenant_id,
        destination: destination
      )

      conn
      |> configure_session(renew: true)
      |> put_session("session_id", session.id)
      |> redirect(to: destination)
    else
      {:error, :already_used} ->
        conn
        |> put_flash(:error, "This link has already been used. Please request a new one.")
        |> redirect(to: ~p"/")

      {:error, :expired} ->
        conn
        |> put_flash(:error, "This link has expired. Please request a new one.")
        |> redirect(to: ~p"/")

      {:error, _} ->
        conn
        |> put_flash(:error, "Invalid magic link.")
        |> redirect(to: ~p"/")

      nil ->
        conn
        |> put_flash(:error, "Account not found.")
        |> redirect(to: ~p"/")
    end
  end

  def magic(conn, _params) do
    conn
    |> put_flash(:error, "Missing token.")
    |> redirect(to: ~p"/")
  end

  @doc "Logs the current user out by deleting their session."
  def logout(conn, _params) do
    session_id = get_session(conn, "session_id")

    if session_id do
      Auth.delete_session(session_id)
      Logger.info("auth.logout", session_id: session_id)
    end

    conn
    |> delete_session("session_id")
    |> put_flash(:info, "You have been logged out.")
    |> redirect(to: ~p"/")
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  # Invited (first login) → collect their name first
  defp post_login_path(%{status: "invited"}, tenant) do
    "/#{tenant.slug}/activate"
  end

  # Active, privacy not accepted → show privacy summary
  defp post_login_path(%{privacy_accepted_at: nil, role: role}, tenant) do
    next = if role == "tenant_admin", do: "/#{tenant.slug}/admin", else: "/#{tenant.slug}/"
    "/#{tenant.slug}/privacy-summary?next=#{URI.encode(next)}"
  end

  # Active, admin → admin panel
  defp post_login_path(%{role: "tenant_admin"}, tenant), do: "/#{tenant.slug}/admin"

  # Active, regular player → dashboard
  defp post_login_path(_profile, tenant), do: "/#{tenant.slug}/"

  # Accepts only relative paths that start with "/" and contain no "://" or leading "//".
  defp safe_return_to(nil), do: nil
  defp safe_return_to(""), do: nil

  defp safe_return_to(path) do
    if String.starts_with?(path, "/") and
         not String.starts_with?(path, "//") and
         not String.contains?(path, "://") do
      path
    else
      nil
    end
  end
end
