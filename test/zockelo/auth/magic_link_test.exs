defmodule Zockelo.Auth.MagicLinkTest do
  use Zockelo.DataCase, async: true

  import Swoosh.TestAssertions

  alias Zockelo.Auth
  alias Zockelo.Auth.MagicLinkToken
  alias Zockelo.Projections.PlayerProfile

  @tenant_id "00000000-0000-0000-0000-000000000001"
  @player_id "00000000-0000-0000-0000-000000000010"
  @email "player@example.com"

  defp insert_profile(player_id \\ @player_id, email \\ @email) do
    {:ok, encrypted} = Zockelo.Crypto.encrypt_field(player_id, email)
    Repo.insert!(%PlayerProfile{
      player_id: player_id,
      tenant_id: @tenant_id,
      encrypted_email: encrypted,
      role: "player",
      status: "active"
    })
  end

  describe "generate_magic_link/3" do
    setup do
      Zockelo.Crypto.generate_player_key(@player_id, @tenant_id)
      insert_profile()
      :ok
    end

    test "creates a token record in the DB" do
      {:ok, _token} = Auth.generate_magic_link(@email, @tenant_id, @player_id)

      assert Repo.aggregate(MagicLinkToken, :count) == 1
    end

    test "returns the raw (unhashed) token" do
      {:ok, raw_token} = Auth.generate_magic_link(@email, @tenant_id, @player_id)

      assert is_binary(raw_token)
      assert byte_size(raw_token) > 20
    end

    test "stores the SHA-256 hash, not the raw token" do
      {:ok, raw_token} = Auth.generate_magic_link(@email, @tenant_id, @player_id)

      token_record = Repo.one!(MagicLinkToken)
      expected_hash = :crypto.hash(:sha256, raw_token) |> Base.url_encode64(padding: false)
      assert token_record.token_hash == expected_hash
    end

    test "sets expiry 15 minutes from now" do
      {:ok, _} = Auth.generate_magic_link(@email, @tenant_id, @player_id)

      token = Repo.one!(MagicLinkToken)
      diff = DateTime.diff(token.expires_at, DateTime.utc_now(), :second)
      assert diff > 800 and diff <= 900
    end

    test "sends an email to the player" do
      {:ok, _} = Auth.generate_magic_link(@email, @tenant_id, @player_id)

      assert_email_sent(to: @email)
    end
  end

  describe "verify_magic_link/1" do
    setup do
      Zockelo.Crypto.generate_player_key(@player_id, @tenant_id)
      insert_profile()
      :ok
    end

    test "valid token returns {:ok, player_id}" do
      {:ok, raw_token} = Auth.generate_magic_link(@email, @tenant_id, @player_id)

      assert {:ok, @player_id} = Auth.verify_magic_link(raw_token)
    end

    test "marks the token as used after verification" do
      {:ok, raw_token} = Auth.generate_magic_link(@email, @tenant_id, @player_id)
      {:ok, _} = Auth.verify_magic_link(raw_token)

      token = Repo.one!(MagicLinkToken)
      assert token.used_at != nil
    end

    test "already-used token returns {:error, :already_used}" do
      {:ok, raw_token} = Auth.generate_magic_link(@email, @tenant_id, @player_id)
      {:ok, _} = Auth.verify_magic_link(raw_token)

      assert {:error, :already_used} = Auth.verify_magic_link(raw_token)
    end

    test "expired token returns {:error, :expired}" do
      {:ok, raw_token} = Auth.generate_magic_link(@email, @tenant_id, @player_id)

      # Manually expire the token
      Repo.update_all(MagicLinkToken, set: [expires_at: DateTime.add(DateTime.utc_now(), -1, :second)])

      assert {:error, :expired} = Auth.verify_magic_link(raw_token)
    end

    test "unknown token returns {:error, :not_found}" do
      assert {:error, :not_found} = Auth.verify_magic_link("not-a-real-token")
    end
  end
end
