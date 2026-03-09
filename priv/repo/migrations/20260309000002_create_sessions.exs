defmodule Zockelo.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :player_id, :uuid, null: false
      add :tenant_id, :uuid, null: false
      add :created_at, :utc_datetime_usec, null: false
      add :last_active_at, :utc_datetime_usec, null: false
      add :expires_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:sessions, [:player_id])
    create index(:sessions, [:tenant_id])
  end
end
