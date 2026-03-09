defmodule Zockelo.Audit.AdminAuditLog do
  @moduledoc "Schema for the admin audit log."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "admin_audit_log" do
    field :actor_id, :binary_id
    field :actor_role, :string
    field :tenant_id, :binary_id
    field :action, :string
    field :target_id, :binary_id
    field :target_type, :string
    field :metadata, :map, default: %{}
    field :performed_at, :utc_datetime_usec
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:actor_id, :actor_role, :tenant_id, :action, :target_id, :target_type, :metadata, :performed_at])
    |> validate_required([:actor_id, :actor_role, :action, :performed_at])
  end
end
