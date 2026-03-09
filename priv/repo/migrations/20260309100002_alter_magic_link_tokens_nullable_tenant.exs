defmodule Zockelo.Repo.Migrations.AlterMagicLinkTokensNullableTenant do
  use Ecto.Migration

  def change do
    alter table(:magic_link_tokens) do
      modify :tenant_id, :uuid, null: true
    end
  end
end
