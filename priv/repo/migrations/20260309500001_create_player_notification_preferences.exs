defmodule Zockelo.Repo.Migrations.CreatePlayerNotificationPreferences do
  use Ecto.Migration

  def change do
    create table(:player_notification_preferences, primary_key: false) do
      add :player_id, :uuid, null: false, primary_key: true
      add :tenant_id, :uuid, null: false, primary_key: true
      add :notification_type, :string, null: false, primary_key: true
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create index(:player_notification_preferences, [:tenant_id, :notification_type])
  end
end
