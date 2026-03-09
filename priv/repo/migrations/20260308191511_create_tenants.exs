defmodule Zockelo.Repo.Migrations.CreateTenants do
  use Ecto.Migration

  def change do
    create table(:tenants, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :slug, :string, null: false
      add :name, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :config, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:tenants, [:slug])
  end
end
