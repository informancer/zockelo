defmodule Zockelo.Projections.GameRound do
  use Ecto.Schema
  import Ecto.Changeset

  schema "game_rounds" do
    field :game_id, :binary_id
    field :tenant_id, :binary_id
    field :position, :integer
    field :team1_front_player_id, :binary_id
    field :team1_back_player_id, :binary_id
    field :team2_front_player_id, :binary_id
    field :team2_back_player_id, :binary_id
    field :team1_score, :integer
    field :team2_score, :integer
    field :team1_rating_delta, :float
    field :team2_rating_delta, :float

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [
      :game_id, :tenant_id, :position,
      :team1_front_player_id, :team1_back_player_id,
      :team2_front_player_id, :team2_back_player_id,
      :team1_score, :team2_score,
      :team1_rating_delta, :team2_rating_delta
    ])
    |> validate_required([:game_id, :tenant_id, :position, :team1_score, :team2_score])
  end
end
