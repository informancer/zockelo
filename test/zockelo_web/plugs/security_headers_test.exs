defmodule ZockeloWeb.SecurityHeadersTest do
  use ZockeloWeb.ConnCase, async: true

  # Task 22.20
  describe "security headers" do
    test "Content-Security-Policy header is present", %{conn: conn} do
      conn = get(conn, ~p"/")

      csp = get_resp_header(conn, "content-security-policy")
      assert csp != []
      assert hd(csp) =~ "default-src"
    end

    test "X-Frame-Options or CSP frame-ancestors is set", %{conn: conn} do
      conn = get(conn, ~p"/")

      frame_options = get_resp_header(conn, "x-frame-options")
      csp = get_resp_header(conn, "content-security-policy") |> Enum.join()
      assert frame_options != [] or (csp =~ "frame-ancestors")
    end

    test "Referrer-Policy header is present", %{conn: conn} do
      conn = get(conn, ~p"/")

      assert get_resp_header(conn, "referrer-policy") != []
    end
  end
end
