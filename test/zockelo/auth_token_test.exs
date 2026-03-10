defmodule Zockelo.AuthTokenTest do
  use Zockelo.DataCase, async: true

  alias Zockelo.Auth
  alias Zockelo.Auth.MagicLinkToken

  # Task 22.41 — constant-time token comparison
  describe "verify_magic_link/1" do
    test "rejects invalid token" do
      assert {:error, _reason} = Auth.verify_magic_link("not_a_valid_token")
    end

    test "rejects empty token" do
      assert {:error, _reason} = Auth.verify_magic_link("")
    end
  end

  # Task 22.70 — magic link expiry (15 minutes)
  describe "magic link expiry" do
    test "expired token is rejected" do
      player_id = Ecto.UUID.generate()
      tenant_id = Ecto.UUID.generate()

      # Generate a valid token
      {:ok, raw_token} = Auth.generate_magic_link(
        "test_#{System.unique_integer()}@example.com",
        tenant_id,
        player_id
      )

      # Manually expire it
      token_hash = :crypto.hash(:sha256, raw_token) |> Base.url_encode64(padding: false)

      Repo.update_all(
        from(t in MagicLinkToken, where: t.token_hash == ^token_hash),
        set: [expires_at: ~U[2000-01-01 00:00:00Z]]
      )

      assert {:error, :expired} = Auth.verify_magic_link(raw_token)
    end

    test "valid token within TTL is accepted" do
      player_id = Ecto.UUID.generate()
      tenant_id = Ecto.UUID.generate()

      {:ok, raw_token} = Auth.generate_magic_link(
        "test_#{System.unique_integer()}@example.com",
        tenant_id,
        player_id
      )

      # Token should be valid immediately after generation
      assert {:ok, ^player_id} = Auth.verify_magic_link(raw_token)
    end
  end
end
