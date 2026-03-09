defmodule Zockelo.Auth.InviteLink do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "invite_links" do
    field :tenant_id, :binary_id
    field :token, :string
    field :created_by, :binary_id
    field :expires_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:tenant_id, :token, :created_by, :expires_at, :revoked_at])
    |> validate_required([:tenant_id, :token, :created_by])
    |> unique_constraint(:token)
  end
end
