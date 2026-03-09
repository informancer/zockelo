defmodule ZockeloWeb.PageControllerTest do
  use ZockeloWeb.ConnCase

  test "GET / renders the getting started page when no super admin exists", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Welcome to Zockelo"
  end
end
