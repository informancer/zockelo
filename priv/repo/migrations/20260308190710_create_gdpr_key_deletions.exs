defmodule Zockelo.Repo.Migrations.CreateGdprKeyDeletions do
  use Ecto.Migration

  def change do
    create table(:gdpr_key_deletions, primary_key: false) do
      add :player_id, :uuid, null: false, primary_key: true
      add :tenant_id, :uuid, null: false
      add :deleted_at, :utc_datetime_usec, null: false
    end

    create index(:gdpr_key_deletions, [:tenant_id])
    create index(:gdpr_key_deletions, [:deleted_at])
  end
end
