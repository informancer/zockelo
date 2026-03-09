defmodule Zockelo.Projections.TenantProjection do
  use Commanded.Projections.Ecto,
    application: Zockelo.CommandedApp,
    repo: Zockelo.Repo,
    name: __MODULE__

  alias Zockelo.Projections.TenantRead

  alias Zockelo.Domain.Events.{
    TenantRegistered,
    TenantRequested,
    TenantApproved,
    TenantRejected,
    TenantConfigUpdated,
    TenantDeletionRequested,
    TenantDeletionCancelled
  }

  project(%TenantRegistered.V1{} = e, _meta, fn multi ->
    Ecto.Multi.insert(multi, :tenant, TenantRead.changeset(%{
      id: e.tenant_id, slug: e.slug, name: e.name, status: "active", config: %{}
    }))
  end)

  project(%TenantRequested.V1{} = e, _meta, fn multi ->
    Ecto.Multi.insert(multi, :tenant, TenantRead.changeset(%{
      id: e.tenant_id, slug: e.slug, name: e.name, status: "pending", config: %{}
    }))
  end)

  project(%TenantApproved.V1{tenant_id: id}, _meta, fn multi ->
    Ecto.Multi.update_all(multi, :tenant,
      tenant_query(id), set: [status: "active"])
  end)

  project(%TenantRejected.V1{tenant_id: id}, _meta, fn multi ->
    Ecto.Multi.update_all(multi, :tenant,
      tenant_query(id), set: [status: "rejected"])
  end)

  project(%TenantConfigUpdated.V1{} = e, _meta, fn multi ->
    Ecto.Multi.run(multi, :tenant, fn repo, _changes ->
      case repo.get(TenantRead, e.tenant_id) do
        nil ->
          {:error, :tenant_not_found}
        tenant ->
          merged = Map.merge(tenant.config || %{}, e.changes)
          repo.update(TenantRead.changeset(tenant, %{config: merged}))
      end
    end)
  end)

  project(%TenantDeletionRequested.V1{tenant_id: id}, _meta, fn multi ->
    Ecto.Multi.update_all(multi, :tenant,
      tenant_query(id), set: [status: "deletion_pending"])
  end)

  project(%TenantDeletionCancelled.V1{tenant_id: id}, _meta, fn multi ->
    Ecto.Multi.update_all(multi, :tenant,
      tenant_query(id), set: [status: "active"])
  end)

  defp tenant_query(id) do
    import Ecto.Query
    from t in TenantRead, where: t.id == ^id
  end
end
