defmodule Zockelo.Repo.Migrations.CreatePlayerProfiles do
  use Ecto.Migration

  def change do
    create table(:player_profiles, primary_key: false) do
      add :player_id, :uuid, null: false, primary_key: true
      add :tenant_id, :uuid, null: false
      add :encrypted_name, :binary
      add :encrypted_email, :binary
      add :role, :string, null: false, default: "player"
      add :status, :string, null: false, default: "invited"
      add :theme, :string

      timestamps(type: :utc_datetime_usec)
    end

    create index(:player_profiles, [:tenant_id])
    create index(:player_profiles, [:tenant_id, :status])
  end
end
