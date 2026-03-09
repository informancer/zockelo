defmodule Zockelo.Projections.PlayerProfile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:player_id, :binary_id, autogenerate: false}
  schema "player_profiles" do
    field :tenant_id, :binary_id
    field :encrypted_name, :binary
    field :encrypted_email, :binary
    field :role, :string
    field :status, :string
    field :theme, :string
    field :privacy_accepted_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [:player_id, :tenant_id, :encrypted_name, :encrypted_email, :role, :status, :theme, :privacy_accepted_at])
    |> validate_required([:player_id, :tenant_id, :role, :status])
  end
end
