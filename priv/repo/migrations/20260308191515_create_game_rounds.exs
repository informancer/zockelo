defmodule Zockelo.Repo.Migrations.CreateGameRounds do
  use Ecto.Migration

  def change do
    create table(:game_rounds) do
      add :game_id, :uuid, null: false
      add :tenant_id, :uuid, null: false
      add :position, :integer, null: false
      add :team1_front_player_id, :uuid
      add :team1_back_player_id, :uuid
      add :team2_front_player_id, :uuid
      add :team2_back_player_id, :uuid
      add :team1_score, :integer, null: false
      add :team2_score, :integer, null: false
      # Per-round Elo delta for player profile rating history (task 4.6)
      add :team1_rating_delta, :float
      add :team2_rating_delta, :float

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:game_rounds, [:game_id])
    create index(:game_rounds, [:tenant_id, :game_id])
    # Position slot queries for player profile history
    create index(:game_rounds, [:team1_front_player_id])
    create index(:game_rounds, [:team1_back_player_id])
    create index(:game_rounds, [:team2_front_player_id])
    create index(:game_rounds, [:team2_back_player_id])
  end
end
