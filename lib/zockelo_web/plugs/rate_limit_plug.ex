defmodule ZockeloWeb.Plugs.RateLimitPlug do
  @moduledoc """
  Rate limiting plug using Hammer.

  Supported actions (pass as `:action` option):
    - `:magic_link`      — 5 requests / 15 minutes per email+IP
    - `:join`            — 10 requests / 15 minutes per IP
    - `:token_verify`    — 20 requests / 15 minutes per IP

  On limit exceeded returns 429 and halts the pipeline.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [text: 2]

  @limits %{
    magic_link: {5, :timer.minutes(15)},
    join: {10, :timer.minutes(15)},
    token_verify: {20, :timer.minutes(15)}
  }

  def init(opts), do: opts

  def call(conn, action: action) do
    {limit, window_ms} = Map.fetch!(@limits, action)
    key = rate_limit_key(conn, action)

    case Hammer.check_rate(key, window_ms, limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_status(429)
        |> text("Too many requests. Please wait and try again.")
        |> halt()
    end
  end

  defp rate_limit_key(conn, :magic_link) do
    email = conn.params["email"] || conn.body_params["email"] || "unknown"
    ip = ip_string(conn)
    "magic_link:#{email}:#{ip}"
  end

  defp rate_limit_key(conn, action) do
    "#{action}:#{ip_string(conn)}"
  end

  defp ip_string(conn) do
    conn.remote_ip
    |> Tuple.to_list()
    |> Enum.join(".")
  end
end
