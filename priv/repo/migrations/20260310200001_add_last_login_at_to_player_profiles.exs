defmodule Zockelo.Repo.Migrations.AddLastLoginAtToPlayerProfiles do
  use Ecto.Migration

  def change do
    alter table(:player_profiles) do
      add :last_login_at, :utc_datetime_usec
    end
  end
end
