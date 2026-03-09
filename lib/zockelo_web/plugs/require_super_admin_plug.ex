defmodule ZockeloWeb.Plugs.RequireSuperAdminPlug do
  @moduledoc """
  Halts with 403 if the current session's player is not a super admin.
  Must run after LoadSessionPlug (requires current_session in assigns).
  """
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias Zockelo.SuperAdmins

  def init(opts), do: opts

  def call(%{assigns: %{current_session: nil}} = conn, _opts) do
    conn |> redirect(to: "/login") |> halt()
  end

  def call(%{assigns: %{current_session: session}} = conn, _opts) do
    if SuperAdmins.super_admin?(session.player_id) do
      conn
    else
      conn |> send_resp(403, "Forbidden") |> halt()
    end
  end
end
