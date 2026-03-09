defmodule ZockeloWeb.Plugs.ConditionalRewritePlug do
  @moduledoc """
  Conditionally applies `Plug.RewriteOn` based on `TRUST_PROXY_HEADERS` env var.
  Only rewrites X-Forwarded-For and X-Forwarded-Proto when explicitly enabled.
  """

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    case Application.get_env(:zockelo, :rewrite_on) do
      nil -> conn
      headers -> Plug.RewriteOn.call(conn, Plug.RewriteOn.init(headers))
    end
  end
end
