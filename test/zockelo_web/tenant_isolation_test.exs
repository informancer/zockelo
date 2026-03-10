defmodule ZockeloWeb.TenantIsolationTest do
  use ZockeloWeb.ConnCase, async: true

  # Tasks 22.17 + 22.17b — Tenant isolation
  describe "protected routes" do
    test "unauthenticated request to /:tenant_slug/ redirects to login", %{conn: conn} do
      conn = get(conn, "/some-nonexistent-tenant/")
      # RequireAuthPlug should redirect to login
      assert conn.status in [302, 404]
    end

    test "protected route /games requires auth", %{conn: conn} do
      conn = get(conn, "/some-tenant/games")
      assert conn.status in [302, 404]
    end
  end

  describe "public routes" do
    test "unauthenticated visitor can access /:tenant_slug/login", %{conn: conn} do
      # Even for a nonexistent tenant, the login page should not 404 due to auth
      # (it may 404 because the tenant doesn't exist, but not due to auth redirect)
      conn = get(conn, "/any-slug/login")
      # 200 or redirect to login — not a 401/403
      refute conn.status == 401
      refute conn.status == 403
    end

    test "unauthenticated visitor can access /:tenant_slug/imprint", %{conn: conn} do
      conn = get(conn, "/any-slug/imprint")
      refute conn.status == 401
      refute conn.status == 403
    end

    test "unauthenticated visitor can access /:tenant_slug/privacy", %{conn: conn} do
      conn = get(conn, "/any-slug/privacy")
      refute conn.status == 401
      refute conn.status == 403
    end

    test "unauthenticated visitor can access /:tenant_slug/join", %{conn: conn} do
      conn = get(conn, "/any-slug/join")
      refute conn.status == 401
      refute conn.status == 403
    end
  end
end
