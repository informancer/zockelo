defmodule ZockeloWeb.RobotsTest do
  use ZockeloWeb.ConnCase, async: true

  # Task 22.36
  describe "GET /robots.txt" do
    test "returns 200 with Disallow: /", %{conn: conn} do
      conn = get(conn, "/robots.txt")

      assert conn.status == 200
      assert conn.resp_body =~ "Disallow: /"
    end
  end
end
