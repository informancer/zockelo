defmodule Zockelo.Auth.MagicLinkToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "magic_link_tokens" do
    field :player_id, :binary_id
    field :tenant_id, :binary_id
    field :token_hash, :string
    field :expires_at, :utc_datetime_usec
    field :used_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:player_id, :tenant_id, :token_hash, :expires_at, :used_at])
    |> validate_required([:player_id, :tenant_id, :token_hash, :expires_at])
    |> unique_constraint(:token_hash)
  end
end
