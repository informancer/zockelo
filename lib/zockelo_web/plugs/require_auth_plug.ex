defmodule ZockeloWeb.Plugs.RequireAuthPlug do
  @moduledoc """
  Halts and redirects to the tenant login page when no session is present.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  def init(opts), do: opts

  def call(%{assigns: %{current_session: nil}} = conn, _opts) do
    tenant_slug = conn.params["tenant_slug"]
    login_path = if tenant_slug, do: "/#{tenant_slug}/login", else: "/login"

    conn
    |> redirect(to: login_path)
    |> halt()
  end

  def call(conn, _opts), do: conn
end
