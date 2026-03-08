defmodule Zockelo.Domain.Commands.RegisterTenant do
  @moduledoc "Create a tenant directly (super admin, direct-creation mode)."
  @enforce_keys [:tenant_id, :slug, :name]
  defstruct [:tenant_id, :slug, :name]
end

defmodule Zockelo.Domain.Commands.RequestTenant do
  @moduledoc "Submit a tenant request (request-approval mode)."
  @enforce_keys [:tenant_id, :slug, :name, :requested_by_email]
  defstruct [:tenant_id, :slug, :name, :requested_by_email]
end

defmodule Zockelo.Domain.Commands.ApproveTenant do
  @moduledoc "Super admin approves a pending tenant request."
  @enforce_keys [:tenant_id, :approved_by]
  defstruct [:tenant_id, :approved_by]
end

defmodule Zockelo.Domain.Commands.RejectTenant do
  @moduledoc "Super admin rejects a pending tenant request."
  @enforce_keys [:tenant_id, :rejected_by]
  defstruct [:tenant_id, :rejected_by, :reason]
end

defmodule Zockelo.Domain.Commands.UpdateTenantConfig do
  @moduledoc "Tenant admin saves updated tenant configuration."
  @enforce_keys [:tenant_id, :changes, :updated_by]
  defstruct [:tenant_id, :changes, :updated_by]
end

defmodule Zockelo.Domain.Commands.RequestTenantDeletion do
  @moduledoc "Tenant admin or super admin initiates tenant deletion."
  @enforce_keys [:tenant_id, :requested_by, :grace_period_hours]
  defstruct [:tenant_id, :requested_by, :grace_period_hours]
end

defmodule Zockelo.Domain.Commands.ConfirmTenantDeletion do
  @moduledoc "Second tenant admin confirms a pending deletion (4-eyes flow)."
  @enforce_keys [:tenant_id, :confirmed_by]
  defstruct [:tenant_id, :confirmed_by]
end

defmodule Zockelo.Domain.Commands.CancelTenantDeletion do
  @moduledoc "Any tenant admin or super admin cancels a pending deletion."
  @enforce_keys [:tenant_id, :cancelled_by]
  defstruct [:tenant_id, :cancelled_by]
end
