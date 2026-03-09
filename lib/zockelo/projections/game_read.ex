defmodule Zockelo.Projections.GameRead do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "games" do
    field :tenant_id, :binary_id
    field :logged_by, :binary_id
    field :team1_players, {:array, :binary_id}
    field :team2_players, {:array, :binary_id}
    field :status, :string
    field :confirmation_mode, :string
    field :rounds_to_win, :integer
    field :points_per_round, :integer
    field :logged_at, :utc_datetime_usec
    field :confirmed_at, :utc_datetime_usec
    field :disputed_at, :utc_datetime_usec
    field :voided_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [
      :id, :tenant_id, :logged_by, :team1_players, :team2_players,
      :status, :confirmation_mode, :rounds_to_win, :points_per_round,
      :logged_at, :confirmed_at, :disputed_at, :voided_at
    ])
    |> validate_required([:id, :tenant_id, :logged_by, :status, :logged_at])
  end
end
