defmodule Zockelo.Repo.Migrations.CreateMagicLinkTokens do
  use Ecto.Migration

  def change do
    create table(:magic_link_tokens, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :player_id, :uuid, null: false
      add :tenant_id, :uuid, null: false
      add :token_hash, :string, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :used_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:magic_link_tokens, [:token_hash])
    create index(:magic_link_tokens, [:player_id])
    create index(:magic_link_tokens, [:tenant_id])
  end
end
