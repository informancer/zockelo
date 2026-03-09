defmodule Zockelo.Projections.TenantRead do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "tenants" do
    field :slug, :string
    field :name, :string
    field :status, :string
    field :config, :map, default: %{}
    field :custom_domain, :string

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [:id, :slug, :name, :status, :config, :custom_domain])
    |> validate_required([:id, :slug, :name, :status])
    |> unique_constraint(:custom_domain)
  end
end
