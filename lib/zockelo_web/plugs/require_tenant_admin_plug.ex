defmodule ZockeloWeb.Plugs.RequireTenantAdminPlug do
  @moduledoc """
  Halts with 403 if the current user is not a tenant admin or super admin.
  Must run after RequireTenantPlug (requires current_user in assigns).
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(%{assigns: %{current_user: user}} = conn, _opts) when not is_nil(user) do
    if user.role in ["tenant_admin", "super_admin"] do
      conn
    else
      conn |> send_resp(403, "Forbidden") |> halt()
    end
  end

  def call(conn, _opts) do
    conn |> send_resp(403, "Forbidden") |> halt()
  end
end
