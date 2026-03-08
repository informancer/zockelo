defmodule Zockelo.Domain.Router do
  use Commanded.Commands.Router

  alias Zockelo.Domain.Aggregates.{Tenant, Player, Game}

  alias Zockelo.Domain.Commands.{
    RegisterTenant,
    RequestTenant,
    ApproveTenant,
    RejectTenant,
    UpdateTenantConfig,
    RequestTenantDeletion,
    ConfirmTenantDeletion,
    CancelTenantDeletion,
    InvitePlayer,
    ActivatePlayer,
    DeletePlayer,
    LogGame,
    ConfirmGame,
    DisputeGame,
    ReinstateGame,
    VoidGame
  }

  # ---------------------------------------------------------------------------
  # Tenant commands → Tenant aggregate
  #
  # Stream name: "tenant-{tenant_id}"
  # Tenants get their own isolated stream identified by their UUID.
  # ---------------------------------------------------------------------------

  dispatch [RegisterTenant, RequestTenant, ApproveTenant, RejectTenant,
            UpdateTenantConfig, RequestTenantDeletion, ConfirmTenantDeletion,
            CancelTenantDeletion],
    to: Tenant,
    identity: :tenant_id

  # ---------------------------------------------------------------------------
  # Player commands → Player aggregate
  #
  # Stream name: "tenant-{tenant_id}-players-{player_id}"
  # Tenant-scoped: each player stream is prefixed with the tenant UUID so that
  # player streams from different tenants never overlap.
  # ---------------------------------------------------------------------------

  dispatch [InvitePlayer, ActivatePlayer, DeletePlayer],
    to: Player,
    identity: &Zockelo.Domain.Router.player_stream_id/1

  # ---------------------------------------------------------------------------
  # Game commands → Game aggregate
  #
  # Stream name: "tenant-{tenant_id}-games-{game_id}"
  # Tenant-scoped: each game stream is prefixed with the tenant UUID so that
  # game streams from different tenants never overlap.
  # ---------------------------------------------------------------------------

  dispatch [LogGame, ConfirmGame, DisputeGame, ReinstateGame, VoidGame],
    to: Game,
    identity: &Zockelo.Domain.Router.game_stream_id/1

  # Stream identity helpers — referenced as named function captures above.
  def player_stream_id(%{tenant_id: tid, player_id: pid}),
    do: "tenant-#{tid}-players-#{pid}"

  def game_stream_id(%{tenant_id: tid, game_id: gid}),
    do: "tenant-#{tid}-games-#{gid}"
end
