defmodule ZockeloWeb.UnsubscribeController do
  @moduledoc """
  One-click unsubscribe endpoint. Exempt from CSRF — protected by HMAC token.

  POST /unsubscribe?player_id=...&tenant_id=...&type=...&token=HMAC
  """
  use ZockeloWeb, :controller

  alias Zockelo.Notifications

  def unsubscribe(conn, %{
        "player_id" => player_id,
        "tenant_id" => tenant_id,
        "type" => notification_type,
        "token" => token
      }) do
    if Notifications.verify_unsubscribe_token(token, player_id, tenant_id, notification_type) do
      Notifications.unsubscribe(player_id, tenant_id, notification_type)
      send_resp(conn, 200, "Unsubscribed successfully.")
    else
      send_resp(conn, 400, "Invalid or expired unsubscribe token.")
    end
  end

  def unsubscribe(conn, _params) do
    send_resp(conn, 400, "Missing required parameters.")
  end
end
