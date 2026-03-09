defmodule Zockelo.Repo.Migrations.CreateSuperAdmins do
  use Ecto.Migration

  def change do
    create table(:super_admins, primary_key: false) do
      add :player_id, :uuid, primary_key: true
      add :encrypted_email, :binary, null: false
      add :created_by, :uuid
      timestamps(updated_at: false)
    end
  end
end
