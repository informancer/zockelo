defmodule Zockelo.Repo.Migrations.CreatePlayerRatings do
  use Ecto.Migration

  def change do
    create table(:player_ratings, primary_key: false) do
      add :player_id, :uuid, null: false, primary_key: true
      add :tenant_id, :uuid, null: false
      add :rating, :integer, null: false, default: 1000
      add :games_played, :integer, null: false, default: 0
      add :wins, :integer, null: false, default: 0
      add :losses, :integer, null: false, default: 0
      add :deleted, :boolean, null: false, default: false

      timestamps(type: :utc_datetime_usec)
    end

    # Primary leaderboard query: all active players in a tenant ordered by rating
    create index(:player_ratings, [:tenant_id, :rating], name: :player_ratings_tenant_rating_idx)
  end
end
