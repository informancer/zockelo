defmodule Zockelo.Domain.Aggregates.PlayerTest do
  use ExUnit.Case, async: true

  alias Zockelo.Domain.Aggregates.Player

  alias Zockelo.Domain.Commands.{InvitePlayer, ActivatePlayer, DeletePlayer}

  alias Zockelo.Domain.Events.{PlayerInvited, PlayerActivated, PlayerDeleted}

  @player_id "00000000-0000-0000-0000-000000000010"
  @tenant_id "00000000-0000-0000-0000-000000000001"
  @encrypted_email "enc:abc123"
  @encrypted_name "enc:xyz789"

  defp new_player, do: %Player{}

  defp invite_cmd do
    %InvitePlayer{
      player_id: @player_id,
      tenant_id: @tenant_id,
      encrypted_email: @encrypted_email,
      invited_by: "admin",
      role: :player
    }
  end

  defp invited_player do
    event = Player.execute(new_player(), invite_cmd())
    Player.apply(new_player(), event)
  end

  defp active_player do
    player = invited_player()
    event = Player.execute(player, %ActivatePlayer{
      player_id: @player_id,
      tenant_id: @tenant_id,
      encrypted_name: @encrypted_name
    })
    Player.apply(player, event)
  end

  # ---------------------------------------------------------------------------
  # InvitePlayer
  # ---------------------------------------------------------------------------

  describe "InvitePlayer" do
    test "emits PlayerInvited event" do
      assert %PlayerInvited.V1{
               player_id: @player_id,
               tenant_id: @tenant_id,
               encrypted_email: @encrypted_email,
               role: :player
             } = Player.execute(new_player(), invite_cmd())
    end

    test "state transitions to :invited" do
      assert invited_player().status == :invited
    end

    test "cannot invite an already invited player" do
      assert {:error, _} = Player.execute(invited_player(), invite_cmd())
    end

    test "cannot invite an already active player" do
      assert {:error, _} = Player.execute(active_player(), invite_cmd())
    end
  end

  # ---------------------------------------------------------------------------
  # ActivatePlayer
  # ---------------------------------------------------------------------------

  describe "ActivatePlayer" do
    test "emits PlayerActivated event" do
      cmd = %ActivatePlayer{player_id: @player_id, tenant_id: @tenant_id, encrypted_name: @encrypted_name}
      assert %PlayerActivated.V1{encrypted_name: @encrypted_name} =
               Player.execute(invited_player(), cmd)
    end

    test "state transitions to :active" do
      assert active_player().status == :active
    end

    test "cannot activate a player who was not invited" do
      cmd = %ActivatePlayer{player_id: @player_id, tenant_id: @tenant_id, encrypted_name: @encrypted_name}
      assert {:error, _} = Player.execute(new_player(), cmd)
    end

    test "cannot activate an already active player" do
      cmd = %ActivatePlayer{player_id: @player_id, tenant_id: @tenant_id, encrypted_name: @encrypted_name}
      assert {:error, _} = Player.execute(active_player(), cmd)
    end
  end

  # ---------------------------------------------------------------------------
  # DeletePlayer
  # ---------------------------------------------------------------------------

  describe "DeletePlayer" do
    test "can delete an invited (not yet active) player" do
      cmd = %DeletePlayer{player_id: @player_id, tenant_id: @tenant_id, deleted_by: "admin"}
      assert %PlayerDeleted.V1{} = Player.execute(invited_player(), cmd)
    end

    test "can delete an active player" do
      cmd = %DeletePlayer{player_id: @player_id, tenant_id: @tenant_id, deleted_by: "admin"}
      assert %PlayerDeleted.V1{} = Player.execute(active_player(), cmd)
    end

    test "state transitions to :deleted" do
      cmd = %DeletePlayer{player_id: @player_id, tenant_id: @tenant_id, deleted_by: "admin"}
      event = Player.execute(active_player(), cmd)
      deleted = Player.apply(active_player(), event)
      assert deleted.status == :deleted
    end

    test "cannot delete an already deleted player" do
      cmd = %DeletePlayer{player_id: @player_id, tenant_id: @tenant_id, deleted_by: "admin"}
      event = Player.execute(active_player(), cmd)
      deleted = Player.apply(active_player(), event)
      assert {:error, :already_deleted} = Player.execute(deleted, cmd)
    end
  end
end
