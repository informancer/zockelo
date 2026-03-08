## ADDED Requirements

### Requirement: Super admin can be bootstrapped via seed script
The system SHALL provide a mix task `zockelo.create_super_admin` that creates the first super admin account given an email address. Running the task when a super admin already exists SHALL be a no-op with a warning.

#### Scenario: First-time bootstrap
- **WHEN** operator runs `mix zockelo.create_super_admin --email admin@example.com` on a fresh install
- **THEN** a super admin account is created and a magic link is sent to that email

#### Scenario: Bootstrap when super admin exists
- **WHEN** operator runs the seed script and a super admin already exists
- **THEN** the system prints a warning and exits without creating a duplicate

### Requirement: Super admin panel shows a getting-started prompt when no tenants exist
When a super admin logs in and no tenants exist yet, the `/admin` panel SHALL display a prominent call-to-action: *"No leagues yet — create your first one"* with a direct link to the create-tenant form. System configuration sections are still accessible but secondary.

#### Scenario: Super admin sees getting-started prompt with no tenants
- **WHEN** a super admin visits `/admin` and no tenants have been created yet
- **THEN** the page shows a prominent "Create your first league" call-to-action above the tenant list (which is empty)

### Requirement: Super admin can create tenants directly
When the system is configured in direct-creation mode, the super admin SHALL be able to create a tenant by providing a name and slug. The first tenant admin SHALL be designated at creation time, either by inviting someone by email (who need not have an existing account) or by selecting an existing player.

#### Scenario: Super admin creates a tenant and invites a new tenant admin by email
- **WHEN** super admin submits the create-tenant form with a unique slug and provides an email address for the first tenant admin
- **THEN** a `TenantRegistered` event is emitted, a `PlayerInvited` event is emitted with the tenant admin role, and a magic link is sent to that email

#### Scenario: Super admin creates a tenant and assigns an existing player as tenant admin
- **WHEN** super admin submits the create-tenant form and selects an existing player as the first tenant admin
- **THEN** a `TenantRegistered` event is emitted and that player is immediately granted the tenant admin role

#### Scenario: Duplicate slug rejected
- **WHEN** super admin attempts to create a tenant with a slug already in use
- **THEN** the system rejects the request with a validation error

#### Scenario: Tenant slug is immutable after creation
- **WHEN** a super admin or tenant admin attempts to change a tenant's slug
- **THEN** the slug field is not editable; no mechanism exists in the UI to change it after creation. This is intentional: slugs are embedded in Caddy custom domain rewrite rules, bookmarks, and shared URLs — changing them silently would break all of these.

### Requirement: Tenant creation via request and approval flow
When the system is configured in request-approval mode, any user SHALL be able to submit a tenant request. The super admin SHALL be able to approve or reject the request. The requester SHALL receive an email notification of the decision in both cases.

#### Scenario: User requests a tenant
- **WHEN** a user submits a tenant request with name, slug, and their email
- **THEN** a `TenantRequested` event is emitted and the super admin is notified by email

#### Scenario: Super admin approves a tenant request
- **WHEN** super admin approves a pending tenant request
- **THEN** a `TenantApproved` event is emitted and the requesting user receives an email with a magic link to activate as the first tenant admin

#### Scenario: Super admin rejects a tenant request
- **WHEN** super admin rejects a pending tenant request
- **THEN** a `TenantRejected` event is emitted and the requesting user receives an email informing them of the rejection

### Requirement: Each tenant has isolated event streams
Each tenant's domain events SHALL be written to dedicated named event streams, isolated from all other tenants. Stream names are prefixed with the tenant UUID:
- `tenant-{tenant_id}-players` — player lifecycle events
- `tenant-{tenant_id}-games` — game events

This isolation ensures that a tenant's event history can be exported, deleted, or migrated independently without touching any other tenant's data. No cross-tenant event stream reads SHALL occur.

#### Scenario: Tenant events written to isolated streams
- **WHEN** a game is logged in tenant A
- **THEN** the `GameLogged` event is appended to `tenant-{tenant_a_id}-games` and is not visible in any other tenant's stream

#### Scenario: Tenant deletion clears only that tenant's streams
- **WHEN** a tenant is deleted
- **THEN** only event streams prefixed with that tenant's UUID are affected; all other tenants' streams remain intact

### Requirement: Tenant has configurable settings
Each tenant SHALL have the following configurable settings stored in tenant config:
- `rounds_to_win` (integer, default: 2)
- `points_per_round` (integer, default: 7)
- `confirmation_mode` (enum: `trust` | `confirmation`, default: `trust`)
- `auto_confirm_after_hours` (integer, default: 24, only relevant in confirmation mode)
- `retention_period_days` (integer, default: 730)
- `notify_admin_on_invite_expiry` (boolean, default: true)
- `default_locale` (enum: `en` | `de`, default: `en`)
- `deletion_grace_period_hours` (integer, default: 48)
- `app_name` (string, optional: displayed in nav, page titles, PWA manifest, and email From display name; defaults to "Zockelo" if unset)
- `custom_domain` (string, optional: fully-qualified domain name, e.g. `foosball.acme.com`; when set, used for magic link URLs and other absolute URL generation; must be unique across all tenants)
- `tenant_creation_mode` (system-level, not per-tenant: `direct` | `request_approval`)

#### Scenario: Tenant admin updates config
- **WHEN** a tenant admin saves updated tenant configuration
- **THEN** the new settings take effect for all subsequent games logged in that tenant

#### Scenario: Duplicate custom_domain rejected
- **WHEN** a tenant admin enters a `custom_domain` value already in use by another tenant
- **THEN** the form returns a validation error and the value is not saved

### Requirement: Custom domain field displays operator setup notice
The `custom_domain` field in the tenant config form SHALL display a persistent inline notice explaining that entering a domain here does not make it active on its own. The notice SHALL state:
1. A DNS record (A or CNAME) must be created pointing the domain at the server's IP address
2. The server operator must update the Caddy configuration to route the domain to this league before it becomes active
3. A link to the operator guide section covering custom domain setup

The notice is informational and SHALL be shown regardless of whether a value is currently set.

#### Scenario: Config form shows custom domain setup notice
- **WHEN** a tenant admin views the tenant config form
- **THEN** the custom_domain field is accompanied by a notice explaining the DNS and operator Caddy steps required

### Requirement: Magic link base URL follows custom_domain transitions
When `custom_domain` is set on a tenant, all newly generated magic links (login, activation, unsubscribe) SHALL use `custom_domain` as the base URL. Previously issued links that used the old base URL remain valid as long as that URL continues to resolve to the application.

When `custom_domain` is cleared, newly generated links revert to using `PHX_HOST` as the base URL. No existing links are invalidated by the change.

#### Scenario: Magic links use custom domain once set
- **WHEN** a tenant has `custom_domain` set and a magic link is generated for a player in that tenant
- **THEN** the link URL uses `custom_domain` as the base (e.g. `https://foosball.acme.com/acme/auth/...`)

#### Scenario: Magic links revert to PHX_HOST when custom domain is cleared
- **WHEN** a tenant admin clears the `custom_domain` field and a magic link is subsequently generated
- **THEN** the link URL uses `PHX_HOST` as the base

### Requirement: Multiple tenant admins are supported
A tenant SHALL support multiple users with the tenant admin role. The super admin SHALL be able to grant or revoke the tenant admin role for any player within any tenant. Tenant admins SHALL be able to grant or revoke the tenant admin role for other players within their own tenant.

#### Scenario: Super admin grants tenant admin role to any player
- **WHEN** super admin assigns the tenant admin role to any player in a tenant via the tenant detail view
- **THEN** that player gains access to the tenant admin panel

#### Scenario: Tenant admin grants tenant admin role
- **WHEN** a tenant admin assigns the admin role to another player in their tenant
- **THEN** that player gains access to the tenant admin panel

#### Scenario: Tenant admin revokes another tenant admin
- **WHEN** a tenant admin removes the admin role from another player
- **THEN** that player loses access to the tenant admin panel but remains a player

### Requirement: Super admin can grant the super admin role to other users
The super admin SHALL be able to grant the super admin role to any existing user. The super admin panel SHALL list all current super admins and allow adding or removing them.

#### Scenario: Super admin promotes a user to super admin
- **WHEN** a super admin grants the super admin role to another user
- **THEN** that user gains full super admin access across all tenants

#### Scenario: Super admin cannot remove the last super admin
- **WHEN** a super admin attempts to remove the super admin role from the only remaining super admin
- **THEN** the system rejects the action with an error to prevent lockout

### Requirement: System-level configuration is manageable via the super admin panel
System-level settings SHALL be configurable through the super admin UI without requiring a code deploy or server restart. Settings include:
- `tenant_creation_mode` (`direct` | `request_approval`)
- `audit_log_retention_days` (integer, default: 730 — 2 years; minimum: 90)

#### Scenario: Super admin changes tenant creation mode
- **WHEN** a super admin updates `tenant_creation_mode` in the system config panel
- **THEN** the new mode takes effect immediately for all subsequent tenant creation attempts

#### Scenario: Super admin sets audit log retention period
- **WHEN** a super admin updates `audit_log_retention_days` in the system config panel
- **THEN** the next scheduled cleanup run purges audit log entries older than the new value

### Requirement: Tenant deletion requires 4-eyes confirmation when multiple admins exist
A tenant admin SHALL be able to initiate tenant deletion. When multiple tenant admins exist, a second tenant admin SHALL confirm before deletion proceeds. When only one tenant admin exists, they may delete directly. A super admin SHALL always be able to initiate deletion unilaterally. All deletion paths include a configurable grace period (default: 48 hours) before data is permanently destroyed.

During the grace period, the deletion MAY be cancelled by any tenant admin or super admin. After the grace period expires, all player keys are crypto-shredded (bulk deletion logged to GDPR audit), sessions revoked, and the tenant slug freed.

#### Scenario: Single admin deletes tenant
- **WHEN** the only tenant admin initiates deletion and confirms the dialog
- **THEN** a `TenantDeletionRequested` event is emitted and the grace period countdown begins

#### Scenario: 4-eyes deletion — second admin confirms
- **WHEN** admin A initiates deletion and admin B (a different tenant admin) confirms
- **THEN** a `TenantDeletionConfirmed` event is emitted and the grace period countdown begins; all other tenant admins are notified by email

#### Scenario: Deletion cancelled during grace period
- **WHEN** any tenant admin or super admin cancels the deletion before the grace period expires
- **THEN** a `TenantDeletionCancelled` event is emitted and the tenant is fully restored

#### Scenario: Deletion executes after grace period
- **WHEN** the grace period expires without cancellation
- **THEN** all player keys are deleted (bulk GDPR audit entries written), all sessions revoked, event streams retained but unreadable, tenant slug freed

#### Scenario: Super admin deletes tenant unilaterally
- **WHEN** a super admin initiates tenant deletion (bypassing 4-eyes requirement)
- **THEN** a `TenantDeletionRequested` event is emitted immediately and the grace period begins; tenant admins are notified by email

### Requirement: Super admin panel shows tenant detail view with player list
The super admin panel SHALL provide a detail view for each tenant showing: tenant config, active player list with roles, game count, last activity date. From this view the super admin SHALL be able to grant or revoke tenant admin role for any player.

#### Scenario: Super admin views tenant detail
- **WHEN** a super admin opens a tenant's detail view
- **THEN** the tenant config, full player list with roles, and activity stats are displayed

#### Scenario: Super admin promotes player to tenant admin from detail view
- **WHEN** a super admin selects a player in the tenant detail view and grants them the tenant admin role
- **THEN** the player immediately gains tenant admin access
