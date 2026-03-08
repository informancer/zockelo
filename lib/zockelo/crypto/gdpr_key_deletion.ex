defmodule Zockelo.Crypto.GdprKeyDeletion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:player_id, :binary_id, autogenerate: false}
  schema "gdpr_key_deletions" do
    field :tenant_id, :binary_id
    field :deleted_at, :utc_datetime_usec
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:player_id, :tenant_id, :deleted_at])
    |> validate_required([:player_id, :tenant_id, :deleted_at])
  end
end
