defmodule Zockelo.Auth.SessionTest do
  use Zockelo.DataCase, async: true

  alias Zockelo.Auth
  alias Zockelo.Auth.Session

  @tenant_id "00000000-0000-0000-0000-000000000001"
  @player_id "00000000-0000-0000-0000-000000000010"

  describe "create_session/2" do
    test "inserts a session row and returns {:ok, session}" do
      assert {:ok, %Session{} = s} = Auth.create_session(@player_id, @tenant_id)
      assert s.player_id == @player_id
      assert s.tenant_id == @tenant_id
      assert s.created_at != nil
      assert s.last_active_at != nil
      assert s.expires_at != nil
    end

    test "absolute expiry is ~7 days from now" do
      {:ok, session} = Auth.create_session(@player_id, @tenant_id)
      diff = DateTime.diff(session.expires_at, DateTime.utc_now(), :hour)
      assert diff > 167 and diff <= 168
    end
  end

  describe "validate_session/1" do
    test "valid session returns {:ok, session}" do
      {:ok, session} = Auth.create_session(@player_id, @tenant_id)

      assert {:ok, %Session{}} = Auth.validate_session(session.id)
    end

    test "unknown session id returns {:error, :not_found}" do
      assert {:error, :not_found} = Auth.validate_session(Ecto.UUID.generate())
    end

    test "absolutely expired session returns {:error, :expired}" do
      {:ok, session} = Auth.create_session(@player_id, @tenant_id)

      # Expire the absolute timeout
      Repo.update_all(Session,
        set: [expires_at: DateTime.add(DateTime.utc_now(), -1, :second)])

      assert {:error, :expired} = Auth.validate_session(session.id)
    end

    test "idle-timed-out session returns {:error, :idle_timeout}" do
      {:ok, session} = Auth.create_session(@player_id, @tenant_id)

      # Push last_active_at beyond idle timeout (default 8 hours)
      Repo.update_all(Session,
        set: [last_active_at: DateTime.add(DateTime.utc_now(), -(8 * 3600 + 1), :second)])

      assert {:error, :idle_timeout} = Auth.validate_session(session.id)
    end
  end

  describe "touch_session/1" do
    test "updates last_active_at" do
      {:ok, session} = Auth.create_session(@player_id, @tenant_id)
      old_ts = session.last_active_at

      # Push last_active_at back in time so we can verify it moves forward
      Repo.update_all(Session,
        set: [last_active_at: DateTime.add(old_ts, -60, :second)])

      :ok = Auth.touch_session(session.id)

      updated = Repo.get!(Session, session.id)
      assert DateTime.compare(updated.last_active_at, DateTime.add(old_ts, -60, :second)) == :gt
    end
  end

  describe "delete_session/1" do
    test "removes the session row" do
      {:ok, session} = Auth.create_session(@player_id, @tenant_id)

      :ok = Auth.delete_session(session.id)

      assert Repo.get(Session, session.id) == nil
    end
  end
end
