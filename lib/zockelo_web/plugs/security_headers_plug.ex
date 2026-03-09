defmodule ZockeloWeb.Plugs.SecurityHeadersPlug do
  @moduledoc """
  Sets security headers beyond Phoenix defaults.

  Phoenix's `put_secure_browser_headers/2` already sets:
    X-Frame-Options, X-XSS-Protection, X-Content-Type-Options, X-Download-Options,
    X-Permitted-Cross-Domain-Policies, Cross-Origin-Window-Policy.

  This plug adds:
    - HSTS (production only)
    - Referrer-Policy
    - Permissions-Policy
    - Content-Security-Policy with nonce, connect-src wss:, and img-src data:
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    nonce = Base.encode64(:crypto.strong_rand_bytes(16))
    host = effective_host()

    conn
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "geolocation=(), microphone=(), camera=()")
    |> maybe_hsts()
    |> put_csp(nonce, host)
    |> assign(:csp_nonce, nonce)
  end

  defp put_csp(conn, nonce, host) do
    csp =
      [
        "default-src 'self'",
        "script-src 'self' 'nonce-#{nonce}'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data:",
        "font-src 'self'",
        "connect-src 'self' wss://#{host}",
        "frame-ancestors 'none'",
        "base-uri 'self'",
        "form-action 'self'"
      ]
      |> Enum.join("; ")

    put_resp_header(conn, "content-security-policy", csp)
  end

  defp maybe_hsts(conn) do
    if Application.get_env(:zockelo, :force_ssl, false) do
      put_resp_header(conn, "strict-transport-security", "max-age=31536000; includeSubDomains")
    else
      conn
    end
  end

  defp effective_host do
    Application.get_env(:zockelo, ZockeloWeb.Endpoint)[:url][:host] ||
      System.get_env("PHX_HOST", "localhost")
  end
end
