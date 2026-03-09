defmodule Zockelo.Auth.Session do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "sessions" do
    field :player_id, :binary_id
    field :tenant_id, :binary_id
    field :created_at, :utc_datetime_usec
    field :last_active_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:player_id, :tenant_id, :created_at, :last_active_at, :expires_at])
    |> validate_required([:player_id, :tenant_id, :created_at, :last_active_at, :expires_at])
  end
end
