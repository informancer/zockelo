defmodule ZockeloWeb.LocalePlugTest do
  use ZockeloWeb.ConnCase, async: true

  alias ZockeloWeb.Plugs.LocalePlug

  # Task 22.15 — locale resolution order: preference → browser → fallback
  describe "call/2" do
    test "falls back to 'en' when no player and no Accept-Language" do
      conn =
        build_conn()
        |> put_req_header("accept-language", "")
        |> LocalePlug.call([])

      assert Gettext.get_locale(ZockeloWeb.Gettext) == "en"
    end

    test "uses Accept-Language header when no player preference" do
      conn =
        build_conn()
        |> put_req_header("accept-language", "de-DE,de;q=0.9,en;q=0.8")
        |> LocalePlug.call([])

      assert Gettext.get_locale(ZockeloWeb.Gettext) == "de"
    end

    test "falls back to 'en' for unsupported Accept-Language" do
      conn =
        build_conn()
        |> put_req_header("accept-language", "zh-CN,zh;q=0.9")
        |> LocalePlug.call([])

      assert Gettext.get_locale(ZockeloWeb.Gettext) == "en"
    end
  end
end
