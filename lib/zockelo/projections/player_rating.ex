defmodule Zockelo.Projections.PlayerRating do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:player_id, :binary_id, autogenerate: false}
  schema "player_ratings" do
    field :tenant_id, :binary_id
    field :rating, :integer, default: 1000
    field :games_played, :integer, default: 0
    field :wins, :integer, default: 0
    field :losses, :integer, default: 0
    field :deleted, :boolean, default: false

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [:player_id, :tenant_id, :rating, :games_played, :wins, :losses, :deleted])
    |> validate_required([:player_id, :tenant_id])
  end
end
