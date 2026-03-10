defmodule Zockelo.PlayersCrlfTest do
  use Zockelo.DataCase, async: true

  alias Zockelo.Players

  # Task 22.43 — CRLF injection rejection
  describe "CRLF injection" do
    test "invite_player rejects email with CRLF" do
      result =
        Players.invite_player(
          Ecto.UUID.generate(),
          "admin@example.com\r\nBcc: evil@example.com",
          Ecto.UUID.generate()
        )

      assert {:error, :crlf_injection} = result
    end

    test "activate_player rejects name with CRLF" do
      player_id = Ecto.UUID.generate()
      tenant_id = Ecto.UUID.generate()

      result = Players.activate_player(player_id, tenant_id, "Name\r\nInjected")

      assert {:error, :crlf_injection} = result
    end
  end
end
