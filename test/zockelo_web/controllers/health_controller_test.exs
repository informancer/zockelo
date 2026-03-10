defmodule ZockeloWeb.HealthControllerTest do
  use ZockeloWeb.ConnCase, async: false

  # Task 22.26
  describe "GET /health" do
    test "returns 200 with status ok when healthy", %{conn: conn} do
      conn = get(conn, ~p"/health")

      assert conn.status == 200
      body = json_response(conn, 200)
      assert body["status"] == "ok"
      # Must NOT contain a "version" field
      refute Map.has_key?(body, "version")
    end
  end
end
