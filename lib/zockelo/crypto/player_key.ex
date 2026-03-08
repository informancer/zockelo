defmodule Zockelo.Crypto.PlayerKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:player_id, :binary_id, autogenerate: false}
  schema "player_keys" do
    field :tenant_id, :binary_id
    field :encrypted_key, :binary
    field :created_at, :utc_datetime_usec
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:player_id, :tenant_id, :encrypted_key, :created_at])
    |> validate_required([:player_id, :tenant_id, :encrypted_key, :created_at])
  end
end
