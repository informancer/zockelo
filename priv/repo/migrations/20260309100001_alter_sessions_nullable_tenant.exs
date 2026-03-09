defmodule Zockelo.Repo.Migrations.AlterSessionsNullableTenant do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      modify :tenant_id, :uuid, null: true
    end
  end
end
