defmodule Zockelo.Repo.Migrations.CreateSystemConfig do
  use Ecto.Migration

  def change do
    create table(:system_config, primary_key: false) do
      add :key, :text, primary_key: true
      add :value, :text, null: false
      timestamps()
    end
  end
end
