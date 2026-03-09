defmodule Zockelo.Tenants do
  @moduledoc """
  Read-side context for tenant data in the admin panel.
  Write-side goes through the Commanded domain router.
  """

  import Ecto.Query

  alias Zockelo.Repo
  alias Zockelo.Projections.{TenantRead, PlayerProfile, PlayerRating}
  alias Zockelo.CommandedApp
  alias Zockelo.Domain.Commands.{
    RegisterTenant,
    RequestTenant,
    ApproveTenant,
    RejectTenant,
    RequestTenantDeletion,
    CancelTenantDeletion
  }

  @grace_period_hours 48

  @doc "Lists all tenants ordered by name."
  def list_tenants do
    Repo.all(from t in TenantRead, order_by: t.name)
  end

  @doc "Lists tenants by status."
  def list_tenants_by_status(status) do
    Repo.all(from t in TenantRead, where: t.status == ^status, order_by: t.name)
  end

  @doc "Gets a tenant by id."
  def get_tenant(id), do: Repo.get(TenantRead, id)

  @doc "Gets a tenant by slug."
  def get_tenant_by_slug(slug), do: Repo.get_by(TenantRead, slug: slug)

  @doc "Creates a tenant directly (super admin, direct mode)."
  def register_tenant(attrs) do
    tenant_id = Ecto.UUID.generate()
    slug = Map.fetch!(attrs, "slug")
    name = Map.fetch!(attrs, "name")

    CommandedApp.dispatch(%RegisterTenant{
      tenant_id: tenant_id,
      slug: slug,
      name: name
    })
    |> case do
      :ok -> {:ok, tenant_id}
      err -> err
    end
  end

  @doc "Submits a tenant request (request-approval mode)."
  def request_tenant(attrs) do
    tenant_id = Ecto.UUID.generate()

    CommandedApp.dispatch(%RequestTenant{
      tenant_id: tenant_id,
      slug: Map.fetch!(attrs, "slug"),
      name: Map.fetch!(attrs, "name"),
      requested_by_email: Map.fetch!(attrs, "requested_by_email")
    })
    |> case do
      :ok -> {:ok, tenant_id}
      err -> err
    end
  end

  @doc "Super admin approves a pending tenant request."
  def approve_tenant(tenant_id, approved_by) do
    CommandedApp.dispatch(%ApproveTenant{
      tenant_id: tenant_id,
      approved_by: approved_by
    })
  end

  @doc "Super admin rejects a pending tenant request."
  def reject_tenant(tenant_id, rejected_by, reason \\ nil) do
    CommandedApp.dispatch(%RejectTenant{
      tenant_id: tenant_id,
      rejected_by: rejected_by,
      reason: reason
    })
  end

  @doc "Initiates tenant deletion with the default grace period."
  def request_deletion(tenant_id, requested_by) do
    CommandedApp.dispatch(%RequestTenantDeletion{
      tenant_id: tenant_id,
      requested_by: requested_by,
      grace_period_hours: @grace_period_hours
    })
  end

  @doc "Cancels a pending tenant deletion."
  def cancel_deletion(tenant_id, cancelled_by) do
    CommandedApp.dispatch(%CancelTenantDeletion{
      tenant_id: tenant_id,
      cancelled_by: cancelled_by
    })
  end

  @doc "Returns players and their roles for a tenant."
  def list_players(tenant_id) do
    Repo.all(
      from p in PlayerProfile,
        where: p.tenant_id == ^tenant_id,
        order_by: p.player_id
    )
  end

  @doc "Returns activity stats for a tenant (player count, game count)."
  def tenant_stats(tenant_id) do
    player_count = Repo.aggregate(
      from(p in PlayerProfile, where: p.tenant_id == ^tenant_id),
      :count
    )
    rating_count = Repo.aggregate(
      from(r in PlayerRating, where: r.tenant_id == ^tenant_id),
      :count
    )
    %{player_count: player_count, game_count: rating_count}
  end
end
