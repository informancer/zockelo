defmodule Zockelo.Domain.Events.TenantRegistered do
  @moduledoc "Emitted when a tenant is created directly by a super admin."
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [:tenant_id, :slug, :name, :registered_at]
    defstruct [:tenant_id, :slug, :name, :registered_at]
  end
end

defmodule Zockelo.Domain.Events.TenantRequested do
  @moduledoc "Emitted when a user submits a tenant request (request-approval mode)."
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [:tenant_id, :slug, :name, :requested_by_email, :requested_at]
    defstruct [:tenant_id, :slug, :name, :requested_by_email, :requested_at]
  end
end

defmodule Zockelo.Domain.Events.TenantApproved do
  @moduledoc "Emitted when a super admin approves a pending tenant request."
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [:tenant_id, :approved_by, :approved_at]
    defstruct [:tenant_id, :approved_by, :approved_at]
  end
end

defmodule Zockelo.Domain.Events.TenantRejected do
  @moduledoc "Emitted when a super admin rejects a pending tenant request."
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [:tenant_id, :rejected_by, :rejected_at]
    defstruct [:tenant_id, :rejected_by, :reason, :rejected_at]
  end
end

defmodule Zockelo.Domain.Events.TenantConfigUpdated do
  @moduledoc "Emitted when a tenant admin saves updated tenant configuration."
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [:tenant_id, :changes, :updated_by, :updated_at]
    defstruct [:tenant_id, :changes, :updated_by, :updated_at]
  end
end

defmodule Zockelo.Domain.Events.TenantDeletionRequested do
  @moduledoc "Emitted when a tenant admin or super admin initiates tenant deletion."
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [:tenant_id, :requested_by, :grace_period_hours, :execute_at, :requested_at]
    defstruct [:tenant_id, :requested_by, :grace_period_hours, :execute_at, :requested_at]
  end
end

defmodule Zockelo.Domain.Events.TenantDeletionConfirmed do
  @moduledoc "Emitted when a second tenant admin confirms the deletion (4-eyes flow)."
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [:tenant_id, :confirmed_by, :confirmed_at]
    defstruct [:tenant_id, :confirmed_by, :confirmed_at]
  end
end

defmodule Zockelo.Domain.Events.TenantDeletionCancelled do
  @moduledoc "Emitted when any tenant admin or super admin cancels a pending deletion."
  defmodule V1 do
    @derive Jason.Encoder
    @enforce_keys [:tenant_id, :cancelled_by, :cancelled_at]
    defstruct [:tenant_id, :cancelled_by, :cancelled_at]
  end
end
