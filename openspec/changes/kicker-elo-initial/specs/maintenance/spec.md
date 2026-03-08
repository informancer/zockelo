## ADDED Requirements

### Requirement: Super admin can set a system-wide maintenance message
The super admin SHALL be able to set a maintenance message in the super admin panel. The message SHALL include a description and an optional scheduled maintenance window (ISO 8601 datetime). While active, the message SHALL be displayed as a dismissable banner on all pages for all users across all tenants. Dismissal is stored client-side per session; the banner reappears if the message is updated.

#### Scenario: Super admin sets maintenance message
- **WHEN** a super admin submits a maintenance message with a scheduled time
- **THEN** the message is saved and the banner appears immediately for all connected clients

#### Scenario: Super admin clears maintenance message
- **WHEN** a super admin clears the maintenance message
- **THEN** the banner is removed from all pages

#### Scenario: Banner is dismissable per session
- **WHEN** a user dismisses the maintenance banner
- **THEN** it no longer appears for that session; if the message is updated it reappears

### Requirement: Super admin can broadcast a maintenance announcement email
The super admin SHALL be able to optionally send a maintenance announcement email to all active players across all tenants when setting a maintenance message. Only players who have the system maintenance announcement notification enabled SHALL receive the email. The email SHALL include `List-Unsubscribe` and `List-Unsubscribe-Post` headers (RFC 8058) so players can opt out of future announcements.

#### Scenario: Super admin broadcasts maintenance email
- **WHEN** a super admin submits a maintenance announcement with "send email" checked
- **THEN** a broadcast email is sent to all active players who have the maintenance announcement notification enabled

#### Scenario: Player opts out of maintenance announcements
- **WHEN** a player disables the system maintenance announcement notification or uses the List-Unsubscribe link in a maintenance email
- **THEN** future maintenance broadcast emails are not sent to that player

### Requirement: Event schemas are explicitly versioned with upcasters for evolution
All event structs SHALL carry an explicit version suffix in their module name (e.g. `GameLogged.V1`). When the schema of an event changes, a new version module SHALL be created (e.g. `GameLogged.V2`) and a Commanded upcaster SHALL be registered to transform stored V1 events to V2 before they are dispatched to handlers. This allows projection rebuilds and schema evolution without modifying historical event data.

#### Scenario: Upcaster transforms old event to new schema
- **WHEN** an old version event is read from the event store during replay
- **THEN** the registered upcaster transforms it to the current version before the handler processes it

#### Scenario: New events written with current version
- **WHEN** a new event is emitted
- **THEN** it is written to the event store as the current version struct

### Requirement: Projection rebuilds require planned downtime and are documented
Full projection rebuilds (drop and replay) SHALL require a planned maintenance window. The procedure SHALL be documented in the operator guide. The maintenance message system SHALL be used to announce the downtime to users before it begins. The operator guide SHALL document:
- How to trigger a projection rebuild
- Expected duration at ~20 players per tenant
- How to verify the rebuild completed successfully

#### Scenario: Operator follows rebuild procedure
- **WHEN** an operator follows the documented projection rebuild procedure
- **THEN** all projections are rebuilt from the event log and the application resumes normal operation

### Requirement: Operator guide documents environment-specific ACME configuration
The operator guide SHALL document how to configure Caddy (or an equivalent reverse proxy) with a custom ACME server for deployments where the server is not reachable from the public internet or the operator uses an internal CA. The documentation SHALL either include the relevant Caddy configuration directives or reference the official Caddy documentation for ACME server override.

#### Scenario: Operator configures internal ACME server
- **WHEN** an operator follows the ACME configuration documentation
- **THEN** they can configure TLS certificate issuance from an internal CA without internet access
