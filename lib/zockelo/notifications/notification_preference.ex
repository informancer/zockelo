defmodule Zockelo.Notifications.NotificationPreference do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "player_notification_preferences" do
    field :player_id, :binary_id, primary_key: true
    field :tenant_id, :binary_id, primary_key: true
    field :notification_type, :string, primary_key: true
    field :enabled, :boolean, default: true

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [:player_id, :tenant_id, :notification_type, :enabled])
    |> validate_required([:player_id, :tenant_id, :notification_type])
  end
end
