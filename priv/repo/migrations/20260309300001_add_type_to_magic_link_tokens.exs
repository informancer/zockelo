defmodule Zockelo.Repo.Migrations.AddTypeToMagicLinkTokens do
  use Ecto.Migration

  def change do
    alter table(:magic_link_tokens) do
      add :token_type, :string, default: "login", null: false
      add :new_email_encrypted, :binary
    end
  end
end
