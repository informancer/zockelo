defmodule Zockelo.Legal.SupervisoryAuthorityTest do
  use ExUnit.Case, async: true

  alias Zockelo.Legal.SupervisoryAuthority

  # Task 22.74
  describe "lookup/1" do
    test "AT returns DSB" do
      assert {:ok, %{name: name, url: url}} = SupervisoryAuthority.lookup("AT")
      assert name =~ "Datenschutzbehörde"
      assert url =~ "dsb.gv.at"
    end

    test "FR returns CNIL" do
      assert {:ok, %{name: name}} = SupervisoryAuthority.lookup("FR")
      assert name =~ "CNIL"
    end

    test "DE returns BfDI with germany_note flag" do
      assert {:ok, auth} = SupervisoryAuthority.lookup("DE")
      assert auth.name =~ "BfDI"
      assert auth.germany_note == true
    end

    test "GB returns ICO" do
      assert {:ok, %{name: name}} = SupervisoryAuthority.lookup("GB")
      assert name =~ "ICO"
    end

    test "unknown code returns :unknown" do
      assert :unknown = SupervisoryAuthority.lookup("ZZ")
    end

    test "nil returns :unknown" do
      assert :unknown = SupervisoryAuthority.lookup(nil)
    end

    test "empty string returns :unknown" do
      assert :unknown = SupervisoryAuthority.lookup("")
    end

    test "lowercase code is normalised" do
      assert {:ok, _} = SupervisoryAuthority.lookup("at")
      assert {:ok, _} = SupervisoryAuthority.lookup("de")
    end
  end
end
