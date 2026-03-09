defmodule Zockelo.Domain.Aggregates.Player do
  @moduledoc """
  Player aggregate. Manages the lifecycle of a player within a tenant.

  State transitions:
    nil → :invited   (InvitePlayer)
    :invited → :active (ActivatePlayer)
    :active | :invited → :deleted (DeletePlayer)

  PII fields (email, name) are stored in events as encrypted ciphertext.
  Key management and crypto-shredding are handled by the Zockelo.Crypto context.
  """

  alias Zockelo.Domain.Commands.{InvitePlayer, ActivatePlayer, DeletePlayer, UpdatePlayerName, ChangePlayerEmail}

  alias Zockelo.Domain.Events.{
    PlayerInvited,
    PlayerActivated,
    PlayerDeleted,
    PlayerNameChanged,
    PlayerEmailChanged
  }

  defstruct [
    :player_id,
    :tenant_id,
    :role,
    :status
  ]

  # ---------------------------------------------------------------------------
  # Command handlers
  # ---------------------------------------------------------------------------

  def execute(%__MODULE__{status: nil}, %InvitePlayer{} = cmd) do
    %PlayerInvited.V1{
      player_id: cmd.player_id,
      tenant_id: cmd.tenant_id,
      encrypted_email: cmd.encrypted_email,
      invited_by: cmd.invited_by,
      role: cmd.role,
      invited_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: :invited}, %ActivatePlayer{} = cmd) do
    %PlayerActivated.V1{
      player_id: cmd.player_id,
      tenant_id: cmd.tenant_id,
      encrypted_name: cmd.encrypted_name,
      activated_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: status}, %DeletePlayer{} = cmd)
      when status in [:invited, :active] do
    %PlayerDeleted.V1{
      player_id: cmd.player_id,
      tenant_id: cmd.tenant_id,
      deleted_by: cmd.deleted_by,
      deleted_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: :deleted}, %DeletePlayer{}) do
    {:error, :already_deleted}
  end

  def execute(%__MODULE__{status: :active}, %UpdatePlayerName{} = cmd) do
    %PlayerNameChanged.V1{
      player_id: cmd.player_id,
      tenant_id: cmd.tenant_id,
      encrypted_name: cmd.encrypted_name,
      changed_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: :active}, %ChangePlayerEmail{} = cmd) do
    %PlayerEmailChanged.V1{
      player_id: cmd.player_id,
      tenant_id: cmd.tenant_id,
      encrypted_email: cmd.encrypted_email,
      changed_at: DateTime.utc_now()
    }
  end

  def execute(%__MODULE__{status: status}, cmd) do
    {:error, {:invalid_state, "Cannot execute #{inspect(cmd.__struct__)} in state #{inspect(status)}"}}
  end

  # ---------------------------------------------------------------------------
  # Event handlers (state mutation)
  # ---------------------------------------------------------------------------

  def apply(%__MODULE__{} = player, %PlayerInvited.V1{} = event) do
    %{player | player_id: event.player_id, tenant_id: event.tenant_id, role: event.role, status: :invited}
  end

  def apply(%__MODULE__{} = player, %PlayerActivated.V1{}) do
    %{player | status: :active}
  end

  def apply(%__MODULE__{} = player, %PlayerDeleted.V1{}) do
    %{player | status: :deleted}
  end

  def apply(%__MODULE__{} = player, %PlayerNameChanged.V1{}), do: player
  def apply(%__MODULE__{} = player, %PlayerEmailChanged.V1{}), do: player
end
