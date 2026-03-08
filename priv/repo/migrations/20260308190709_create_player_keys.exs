defmodule Zockelo.Repo.Migrations.CreatePlayerKeys do
  use Ecto.Migration

  def change do
    create table(:player_keys, primary_key: false) do
      add :player_id, :uuid, null: false, primary_key: true
      add :tenant_id, :uuid, null: false
      add :encrypted_key, :binary, null: false
      add :created_at, :utc_datetime_usec, null: false
    end

    create index(:player_keys, [:tenant_id])
  end
end
