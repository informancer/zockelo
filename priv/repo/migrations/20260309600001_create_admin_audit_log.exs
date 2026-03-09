defmodule Zockelo.Repo.Migrations.CreateAdminAuditLog do
  use Ecto.Migration

  def change do
    create table(:admin_audit_log, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :actor_id, :uuid, null: false
      add :actor_role, :string, null: false
      add :tenant_id, :uuid
      add :action, :string, null: false
      add :target_id, :uuid
      add :target_type, :string
      add :metadata, :jsonb, default: "{}"
      add :performed_at, :utc_datetime_usec, null: false
    end

    create index(:admin_audit_log, [:actor_id])
    create index(:admin_audit_log, [:tenant_id])
    create index(:admin_audit_log, [:performed_at])
  end
end
