defmodule Zockelo.Repo.Migrations.AddCustomDomainToTenants do
  use Ecto.Migration

  def change do
    alter table(:tenants) do
      add :custom_domain, :string
    end

    create unique_index(:tenants, [:custom_domain])
  end
end
