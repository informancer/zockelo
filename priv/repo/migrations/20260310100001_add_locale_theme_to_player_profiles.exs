defmodule Zockelo.Repo.Migrations.AddLocaleThemeToPlayerProfiles do
  use Ecto.Migration

  def change do
    alter table(:player_profiles) do
      add :locale, :string, default: "en"
    end
  end
end
