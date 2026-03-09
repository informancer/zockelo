defmodule Zockelo.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :tenant_id, :uuid, null: false
      add :logged_by, :uuid, null: false
      add :team1_players, {:array, :uuid}, null: false, default: []
      add :team2_players, {:array, :uuid}, null: false, default: []
      add :status, :string, null: false, default: "pending"
      add :confirmation_mode, :string, null: false
      add :rounds_to_win, :integer, null: false
      add :points_per_round, :integer, null: false
      add :logged_at, :utc_datetime_usec, null: false
      add :confirmed_at, :utc_datetime_usec
      add :disputed_at, :utc_datetime_usec
      add :voided_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    # Game history list — primary query
    create index(:games, [:tenant_id, :logged_at],
      name: :games_tenant_logged_at_idx)

    # Lookup a specific game within a tenant
    create index(:games, [:tenant_id, :id],
      name: :games_tenant_id_idx)

    # Pending/disputed games per tenant (filtered query)
    create index(:games, [:tenant_id, :status],
      name: :games_tenant_status_idx)
  end
end
