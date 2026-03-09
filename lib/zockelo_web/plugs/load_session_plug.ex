defmodule ZockeloWeb.Plugs.LoadSessionPlug do
  @moduledoc """
  Reads the session ID from the Phoenix session and validates it.
  Assigns `:current_session` (an `Auth.Session` struct) or `nil`.
  """
  import Plug.Conn

  alias Zockelo.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, "session_id") do
      nil ->
        assign(conn, :current_session, nil)

      session_id ->
        case Auth.validate_session(session_id) do
          {:ok, session} ->
            Auth.touch_session(session_id)
            assign(conn, :current_session, session)

          {:error, _} ->
            conn
            |> delete_session("session_id")
            |> assign(:current_session, nil)
        end
    end
  end
end
