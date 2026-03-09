defmodule Zockelo.SuperAdmins.SuperAdmin do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:player_id, :binary_id, autogenerate: false}
  schema "super_admins" do
    field :encrypted_email, :binary
    field :created_by, :binary_id

    timestamps(updated_at: false)
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:player_id, :encrypted_email, :created_by])
    |> validate_required([:player_id, :encrypted_email])
  end
end
