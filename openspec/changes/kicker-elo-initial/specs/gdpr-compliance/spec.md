## ADDED Requirements

### Requirement: PII in events is encrypted with per-player keys
All personally identifiable information (name, email) stored in events SHALL be encrypted using AES-256-GCM with a per-player encryption key. Per-player keys SHALL be envelope-encrypted with a system master key using Cloak/Cloak.Ecto. The master key SHALL be provided via environment variable and never stored in the database.

#### Scenario: Event PII is unreadable without the key
- **WHEN** an event containing name or email is read from the event store without access to the player's encryption key
- **THEN** the PII fields contain ciphertext that cannot be decoded

#### Scenario: Event PII is readable with valid key
- **WHEN** the projection processes an event for a player whose key exists in `player_keys`
- **THEN** the name and email decrypt successfully

### Requirement: Player key deletion constitutes GDPR erasure
Deleting a player's encryption key from `player_keys` SHALL constitute erasure of their PII for GDPR purposes. The event stream SHALL NOT be modified. All subsequent reads of that player's events SHALL gracefully return `[Deleted Player]` for name and nil for email.

#### Scenario: Deleted player's events are unreadable
- **WHEN** a player's key is deleted and the projection processes their historical events
- **THEN** name decryption fails gracefully and the player is represented as `[Deleted Player]`

### Requirement: Key deletion is logged for GDPR audit
The system SHALL maintain a `gdpr_key_deletions` table recording every player key deletion. Each record SHALL contain: player_id (UUID), tenant_id (UUID), deleted_at (UTC timestamp). This table SHALL be retained permanently and SHALL NOT be purged.

#### Scenario: Key deletion is auditable
- **WHEN** a player is deleted and their key is removed
- **THEN** a record is inserted into `gdpr_key_deletions` with the player_id, tenant_id, and UTC timestamp

#### Scenario: Audit log is queryable by tenant admin
- **WHEN** a tenant admin requests a GDPR audit report for their tenant
- **THEN** the system returns a list of all key deletion events for that tenant with timestamps

### Requirement: Player can export all their personal data (GDPR Article 20)
A player SHALL be able to download a complete export of all their personal data in JSON format. The export SHALL be generated synchronously and downloaded directly. The export SHALL include:
- Profile data: name, email, tenant, joined_at
- Current rating, games played, wins, losses
- Full game history: date, teams, per-round scores, rating before/after for each game
- Games logged by this player (as the submitter)

The export SHALL NOT include data about other players beyond what is necessary to describe game context (other player names in shared games are included as they are part of the requesting player's own data record).

#### Scenario: Player downloads their data export
- **WHEN** an authenticated player requests a data export from their profile page
- **THEN** the system generates a JSON file containing all their personal data and triggers a browser download

#### Scenario: Export includes full game history with rating deltas
- **WHEN** a player downloads their data export
- **THEN** each game entry includes the date, opponent names, per-round scores, and the player's rating before and after the game

#### Scenario: Tenant admin cannot export data on behalf of another player
- **WHEN** a tenant admin attempts to access another player's data export URL
- **THEN** the system denies access with a 403 response; only the player themselves can export their own data

### Requirement: All operational token and session data has explicit retention limits
The system SHALL enforce the following retention periods for operational data, satisfying Art. 5(1)(e) storage limitation:

| Data type | Retention | Mechanism |
|---|---|---|
| Magic link tokens | 15 minutes from issuance | Expiry field; expired tokens deleted by daily cleanup job |
| Session cookies | Idle timeout 8 hours; absolute max 7 days | Phoenix session config |
| Shareable invite link tokens | Per-token configurable expiry (default: 30 days); no-expiry option available | Expiry field; expired tokens deleted by daily cleanup job |
| Player account data | Until account deletion or `retention_period_days` inactivity (default: 730 days) | Crypto-shredding on deletion; inactivity cleanup worker |
| Admin audit log entries | `audit_log_retention_days` (default: 730 days, min: 90 days) | Daily cleanup worker |
| GDPR key deletion records (`gdpr_key_deletions`) | Permanent | Never purged |

All token expiry times and session lifetimes SHALL be documented in the privacy notice as concrete values, not vague descriptions.

#### Scenario: Expired magic link token is rejected
- **WHEN** a player attempts to verify a magic link token that was issued more than 15 minutes ago
- **THEN** the system rejects the token with an "expired" error and the player must request a new link

#### Scenario: Session absolute max lifetime enforced
- **WHEN** a session has been active for more than 7 days regardless of activity
- **THEN** the session is invalidated and the player must re-authenticate

#### Scenario: Expired invite links are cleaned up
- **WHEN** the daily cleanup job runs
- **THEN** invite link tokens past their expiry date are deleted from the database

### Requirement: Only strictly necessary cookies are used — no consent banner required
The system SHALL use only a single strictly necessary HTTP-only session cookie for authentication. No tracking, analytics, or third-party cookies SHALL be set. Strictly necessary cookies are exempt from consent requirements under ePrivacy/TTDSG. The privacy notice SHALL document this cookie explicitly (name, purpose, idle timeout of 8 hours, absolute maximum lifetime of 7 days).

#### Scenario: No consent banner shown
- **WHEN** any user visits any page of the application
- **THEN** no cookie consent banner or popup is displayed

#### Scenario: Privacy notice documents the session cookie
- **WHEN** a user views the privacy notice
- **THEN** the system-generated section lists the session cookie with its name, purpose (authentication), and lifetime

### Requirement: Inactive accounts are automatically deleted after a configurable retention period
The system SHALL automatically delete player accounts that have been inactive (no login) for longer than a configurable retention period. The retention period SHALL be configurable per tenant (default: 730 days / 2 years). Deletion SHALL follow the existing crypto-shredding deletion flow.

Before deletion, the system SHALL send a warning email to the player at least 30 days in advance. If the player logs in before the deadline, the inactivity clock SHALL reset and deletion SHALL be cancelled.

The system SHALL track `last_login_at` per player, updated on every successful magic link authentication.

#### Scenario: Warning email sent before inactive account deletion
- **WHEN** a player's `last_login_at` is within 30 days of the retention threshold
- **THEN** a warning email is sent informing them their account will be deleted and how to keep it active

#### Scenario: Login resets inactivity clock
- **WHEN** a player logs in after receiving a warning email but before the deletion deadline
- **THEN** their `last_login_at` is updated and the scheduled deletion is cancelled

#### Scenario: Inactive account is deleted after retention period
- **WHEN** a player has not logged in for longer than the tenant's retention period and the 30-day warning period has elapsed without a login
- **THEN** the player's account is deleted via the crypto-shredding deletion flow

#### Scenario: Tenant admin configures retention period
- **WHEN** a tenant admin sets a custom retention period in tenant config
- **THEN** the new period applies to all subsequent inactivity checks for that tenant

### Requirement: Data Processing Agreements (DPA) are not required for self-hosted deployments
When each tenant self-hosts their own KickerElo instance, the tenant organisation acts as both data controller and data processor. No DPA is required in this configuration. This SHALL be documented in the operator documentation.

Note: if KickerElo is ever offered as a hosted SaaS service where one party hosts the system on behalf of another, a DPA under GDPR Art. 28 would be required between the hoster and each tenant organisation. This is out of scope for the current self-hosted architecture.

#### Scenario: Self-hosted deployment has no DPA requirement
- **WHEN** a tenant operates their own self-hosted KickerElo instance
- **THEN** no DPA is required as the tenant is both controller and processor

### Requirement: Admin audit log entries are retained for a bounded period then purged
Entries in `admin_audit_log` SHALL be retained for a configurable period (`audit_log_retention_days`, system-level setting, default: 730 days / 2 years, minimum: 90 days) and then purged by the daily cleanup job. This satisfies both GDPR Art. 5(1)(e) storage limitation (data not kept longer than necessary) and the accountability purpose that justifies retention in the first place. The right to erasure (GDPR Art. 17) does not apply to individual audit entries because their retention for the configured period is necessary for accountability, constituting a legitimate interest under Art. 6(1)(f) that overrides the individual's erasure right per Art. 17(3). Deleting audit entries when an actor is deleted would undermine the integrity of the security audit trail. However, entries are automatically purged once the retention period expires, satisfying Art. 5(1)(e) storage limitation.

After an actor's player profile and encryption key are deleted, their `actor_id` UUID in the audit log becomes effectively pseudonymous — the link to their name and email has been severed by crypto-shredding. The UUID alone is no longer directly identifying.

When the admin audit log is displayed in the UI and an `actor_id` no longer resolves to an active player profile, it SHALL be rendered as `[Deleted Admin]`.

The privacy notice SHALL disclose that admin audit log entries are retained for the configured period for accountability purposes even after account deletion, and SHALL state both the retention duration and the legal basis (legitimate interests — Art. 6(1)(f)).

#### Scenario: Audit log entries survive actor deletion within retention period
- **WHEN** an admin who performed logged actions is subsequently deleted
- **THEN** the audit log entries remain intact until the retention period expires; the deleted admin's `actor_id` is displayed as `[Deleted Admin]` in the audit log UI

#### Scenario: Audit log entries are purged after retention period
- **WHEN** the daily cleanup job runs and audit log entries are older than `audit_log_retention_days`
- **THEN** those entries are deleted regardless of whether the actor still exists

#### Scenario: Audit log integrity is not affected by actor deletion within retention period
- **WHEN** a player is deleted and they previously performed auditable admin actions
- **THEN** those audit entries are not removed or modified until the retention period expires; the action, target, and timestamp remain accurate

### Requirement: GDPR data export includes audit log entries where the player was the actor
When a player exports their personal data (GDPR Art. 20), the export SHALL include all `admin_audit_log` entries where that player is the `actor_id`. These records were generated by the player's own actions and constitute their personal data for portability purposes.

#### Scenario: Data export includes admin actions performed by the player
- **WHEN** a player who has performed admin actions downloads their data export
- **THEN** the JSON export includes a section listing each admin action they performed, with action type, target, and timestamp

### Requirement: Player deletion clears all operational data
In addition to key deletion, player deletion SHALL:
1. Revoke all active sessions for that player
2. Delete all pending magic link tokens associated with that player's email
3. Remove the player from the `player_profiles` read model (or mark as deleted)

#### Scenario: Deleted player cannot log in
- **WHEN** a deleted player attempts to request a magic link
- **THEN** the system does not send a magic link (email not found in active players)
