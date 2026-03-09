defmodule Zockelo.Repo.Migrations.CreateInviteLinks do
  use Ecto.Migration

  def change do
    create table(:invite_links, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :tenant_id, :uuid, null: false
      add :token, :string, null: false
      add :created_by, :uuid, null: false
      add :expires_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:invite_links, [:token])
    create index(:invite_links, [:tenant_id])
  end
end
