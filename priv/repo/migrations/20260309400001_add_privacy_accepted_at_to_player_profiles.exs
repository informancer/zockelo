defmodule Zockelo.Repo.Migrations.AddPrivacyAcceptedAtToPlayerProfiles do
  use Ecto.Migration

  def change do
    alter table(:player_profiles) do
      add :privacy_accepted_at, :utc_datetime_usec
    end
  end
end
