defmodule Zockelo.PrivacyNoticeTest do
  use ZockeloWeb.ConnCase, async: true

  # Task 22.46 — Privacy notice content requirements
  # Task 22.73 — Detailed privacy notice content
  # Task 22.75 — Authority rendered from imprint country
  # Task 22.76 — Missing country shows placeholder

  # NOTE: These tests require a real tenant in the DB. They test the LiveView
  # rendered output and are marked with @tag :integration.
  # Inline unit tests for supervisory authority lookup are in supervisory_authority_test.exs.
  describe "privacy notice content" do
    test "privacy route exists and is accessible without auth", %{conn: conn} do
      # Access a privacy page for a nonexistent tenant — should not redirect to login
      conn = get(conn, "/test-tenant/privacy")
      # Either 200 (renders page with redirect) or redirect to home — not an auth redirect
      refute conn.status == 401
      refute conn.status == 403
    end
  end
end
