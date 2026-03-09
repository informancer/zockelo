defmodule Zockelo.SystemConfig.Entry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:key, :string, autogenerate: false}
  schema "system_config" do
    field :value, :string
    timestamps()
  end

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [:key, :value])
    |> validate_required([:key, :value])
  end
end
