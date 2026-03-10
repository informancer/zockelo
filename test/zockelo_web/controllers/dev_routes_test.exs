defmodule ZockeloWeb.DevRoutesTest do
  use ZockeloWeb.ConnCase, async: true

  # Task 22.44 — Dev routes unavailable in test env
  describe "/dev routes" do
    test "GET /dev/dashboard returns 404 in test env", %{conn: conn} do
      conn = get(conn, "/dev/dashboard")
      assert conn.status == 404
    end

    test "GET /dev/mailbox returns 404 in test env", %{conn: conn} do
      conn = get(conn, "/dev/mailbox")
      assert conn.status == 404
    end
  end
end
