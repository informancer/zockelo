defmodule ZockeloWeb.Plugs.PlugTest do
  use ZockeloWeb.ConnCase, async: true

  alias Zockelo.Auth
  alias Zockelo.Repo
  alias Zockelo.Projections.{PlayerProfile, TenantRead}
  alias ZockeloWeb.Plugs.{LoadSessionPlug, RequireAuthPlug, RequireTenantPlug}

  @tenant_id "00000000-0000-0000-0000-000000000001"
  @player_id "00000000-0000-0000-0000-000000000010"

  # Helper: simulates a fetched Phoenix session
  defp with_session(conn, map \\ %{}) do
    conn
    |> Plug.Conn.put_private(:plug_session, map)
    |> Plug.Conn.put_private(:plug_session_fetch, :done)
  end

  defp insert_tenant do
    Repo.insert!(%TenantRead{id: @tenant_id, slug: "acme", name: "Acme FC", status: "active"})
  end

  defp insert_profile(role \\ "player") do
    Repo.insert!(%PlayerProfile{
      player_id: @player_id, tenant_id: @tenant_id,
      role: role, status: "active"
    })
  end

  # -------------------------------------------------------------------------
  # LoadSessionPlug
  # -------------------------------------------------------------------------

  describe "LoadSessionPlug — no session" do
    test "assigns current_session nil", %{conn: conn} do
      conn = conn |> with_session() |> LoadSessionPlug.call(%{})
      assert conn.assigns[:current_session] == nil
    end
  end

  describe "LoadSessionPlug — valid session" do
    test "loads the session and assigns it", %{conn: conn} do
      {:ok, session} = Auth.create_session(@player_id, @tenant_id)

      conn =
        conn
        |> with_session(%{"session_id" => session.id})
        |> LoadSessionPlug.call(%{})

      assert conn.assigns.current_session.id == session.id
    end
  end

  describe "LoadSessionPlug — expired session" do
    test "assigns current_session nil", %{conn: conn} do
      {:ok, session} = Auth.create_session(@player_id, @tenant_id)
      Zockelo.Repo.update_all(Zockelo.Auth.Session,
        set: [expires_at: DateTime.add(DateTime.utc_now(), -1, :second)])

      conn =
        conn
        |> with_session(%{"session_id" => session.id})
        |> LoadSessionPlug.call(%{})

      assert conn.assigns[:current_session] == nil
    end
  end

  # -------------------------------------------------------------------------
  # RequireAuthPlug
  # -------------------------------------------------------------------------

  describe "RequireAuthPlug — no session" do
    test "halts and redirects to login", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"tenant_slug" => "acme"})
        |> Plug.Conn.assign(:current_session, nil)
        |> RequireAuthPlug.call(%{})

      assert conn.halted
      assert redirected_to(conn) =~ "/acme/login"
    end

    test "redirects to root login when no tenant slug", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{})
        |> Plug.Conn.assign(:current_session, nil)
        |> RequireAuthPlug.call(%{})

      assert conn.halted
    end
  end

  describe "RequireAuthPlug — authenticated" do
    test "passes through with a valid session", %{conn: conn} do
      {:ok, session} = Auth.create_session(@player_id, @tenant_id)

      conn =
        conn
        |> Plug.Conn.assign(:current_session, session)
        |> RequireAuthPlug.call(%{})

      refute conn.halted
    end
  end

  # -------------------------------------------------------------------------
  # RequireTenantPlug
  # -------------------------------------------------------------------------

  describe "RequireTenantPlug — valid member" do
    test "assigns current_tenant and current_user", %{conn: conn} do
      insert_tenant()
      insert_profile()
      {:ok, session} = Auth.create_session(@player_id, @tenant_id)

      conn =
        conn
        |> Map.put(:params, %{"tenant_slug" => "acme"})
        |> Plug.Conn.assign(:current_session, session)
        |> RequireTenantPlug.call(%{})

      refute conn.halted
      assert conn.assigns.current_tenant.id == @tenant_id
      assert conn.assigns.current_user.player_id == @player_id
    end
  end

  describe "RequireTenantPlug — not a member" do
    test "returns 404", %{conn: conn} do
      insert_tenant()
      # No profile for this player in this tenant
      {:ok, session} = Auth.create_session(@player_id, @tenant_id)

      conn =
        conn
        |> Map.put(:params, %{"tenant_slug" => "acme"})
        |> Plug.Conn.assign(:current_session, session)
        |> RequireTenantPlug.call(%{})

      assert conn.halted
      assert conn.status == 404
    end
  end

  describe "RequireTenantPlug — unknown tenant slug" do
    test "returns 404", %{conn: conn} do
      {:ok, session} = Auth.create_session(@player_id, @tenant_id)

      conn =
        conn
        |> Map.put(:params, %{"tenant_slug" => "nonexistent"})
        |> Plug.Conn.assign(:current_session, session)
        |> RequireTenantPlug.call(%{})

      assert conn.halted
      assert conn.status == 404
    end
  end
end
