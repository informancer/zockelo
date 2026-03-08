## ADDED Requirements

### Requirement: Tenant admin can invite a player by email
A tenant admin SHALL be able to invite a player by entering their name and email. This emits a `PlayerInvited` event and sends a magic link for activation.

#### Scenario: Admin invites a new player
- **WHEN** a tenant admin submits a name and email address for a new player
- **THEN** a `PlayerInvited` event is emitted and a magic link is sent to that email

#### Scenario: Duplicate email rejected within a tenant
- **WHEN** a tenant admin invites an email address already registered in the tenant
- **THEN** the system rejects the invitation with a validation error

### Requirement: Player activates their account via magic link
An invited player SHALL activate their account by clicking the magic link sent to their email. This emits a `PlayerActivated` event.

#### Scenario: Player activates account
- **WHEN** an invited player clicks their activation magic link
- **THEN** a `PlayerActivated` event is emitted and the player can log games and view the leaderboard

### Requirement: Players can self-register via a shareable invite link
A tenant admin SHALL be able to generate a multi-use invite link for their tenant. The link SHALL be:
- Shareable (distributed by any means)
- Valid for unlimited uses until rotated or expired
- Optionally configurable with an expiry date (default: **no expiry**)
- Rotatable on demand (the old link is immediately invalidated)

The invite link URL format SHALL be `/:tenant_slug/join?code={token}` where `{token}` is a Base64URL-encoded cryptographically secure random value.

A player visiting the invite link SHALL be prompted to enter their name and email address. Submitting the form emits a `PlayerInvited` event and sends a magic link to that email. Clicking the magic link emits a `PlayerActivated` event and begins the session.

Visiting an expired or revoked invite link SHALL render an error page: *"This invite link is no longer valid. Ask your league administrator for a new one."*

#### Scenario: Player self-registers via invite link
- **WHEN** a new user visits `/:tenant_slug/join?code={valid_token}` and submits their name and email
- **THEN** a `PlayerInvited` event is emitted and a magic link is sent to their email

#### Scenario: Player activates via self-registration magic link
- **WHEN** the self-registering player clicks the magic link
- **THEN** a `PlayerActivated` event is emitted and the player is logged in

#### Scenario: Expired invite link shows error page
- **WHEN** a user visits an invite link that has passed its expiry date
- **THEN** the system renders "This invite link is no longer valid" and does not allow registration

#### Scenario: Revoked invite link shows error page
- **WHEN** a user visits an invite link that has been rotated or manually revoked
- **THEN** the system renders the same "no longer valid" error page

#### Scenario: Tenant admin rotates invite link
- **WHEN** a tenant admin rotates the invite link from the admin panel
- **THEN** the previous link is immediately invalidated and a new link is generated with a new token

### Requirement: Invite link management is a dedicated section of the admin panel
The tenant admin panel SHALL include an **Invite link** section containing:

- The current invite link URL, displayed in full and accompanied by a **Copy** button (copies to clipboard)
- An optional **expiry date** field showing the current expiry (or "No expiry" if unset), with an inline edit control to set or clear it
- A **Rotate** button that, when clicked, shows an inline confirmation prompt — *"Rotate invite link? The current link will stop working immediately."* — with Confirm and Cancel actions. On confirmation, the old token is invalidated, a new token is generated, and the new URL is displayed immediately in place of the old one.
- If no invite link has been generated yet (fresh tenant), the section shows a **Generate invite link** button instead.

The invite link section SHALL be absent from the admin panel entirely if the tenant's self-registration is disabled (per tenant config).

#### Scenario: Admin copies the current invite link
- **WHEN** a tenant admin opens the admin panel invite link section
- **THEN** the full invite URL is visible and a Copy button places it on the clipboard

#### Scenario: Admin sets an expiry on the invite link
- **WHEN** a tenant admin sets an expiry date on the invite link
- **THEN** the link remains valid until that date; visits after the expiry date render the "no longer valid" error page

#### Scenario: Admin clears the expiry date
- **WHEN** a tenant admin clears the expiry date field
- **THEN** the invite link has no expiry and remains valid indefinitely until rotated

#### Scenario: Rotation confirmation prevents accidental invalidation
- **WHEN** a tenant admin clicks Rotate
- **THEN** an inline confirmation prompt is shown before any action is taken; the link is only invalidated after the admin confirms

#### Scenario: New link displayed immediately after rotation
- **WHEN** a tenant admin confirms rotation
- **THEN** the new invite URL appears in the section immediately; the admin can copy it without navigating away

#### Scenario: Fresh tenant with no link yet
- **WHEN** a tenant admin opens the invite link section and no link has been generated
- **THEN** a "Generate invite link" button is shown; clicking it creates the first token and displays the URL

### Requirement: Player data is stored with crypto-shredding
PII fields (name, email) in events SHALL be encrypted using a per-player AES-256 key. Keys SHALL be envelope-encrypted with a system master key via Cloak. The raw player UUID and tenant UUID SHALL never be encrypted.

#### Scenario: Player event contains encrypted PII
- **WHEN** a `PlayerInvited` event is written to the event store
- **THEN** the name and email fields are AES-256 encrypted with the player's key; the player_id and tenant_id are stored in plaintext

### Requirement: Player can be deleted (GDPR right to erasure)
A tenant admin or super admin SHALL be able to delete a player. Deletion SHALL:
1. Emit a `PlayerDeleted` event (contains only player_id, tenant_id — no PII)
2. Delete the player's encryption key from the `player_keys` table
3. Log the key deletion timestamp in a GDPR audit table
4. Revoke all active sessions for that player
5. Delete any pending magic link tokens for that player's email

The event stream SHALL NOT be modified. Projections SHALL render the player as `[Deleted Player]`.

#### Scenario: Admin deletes a player
- **WHEN** a tenant admin triggers deletion for a player
- **THEN** a `PlayerDeleted` event is emitted, the encryption key is deleted, the deletion is logged, and the player's sessions are revoked

#### Scenario: Deleted player appears anonymised in history
- **WHEN** the leaderboard or game history renders a deleted player's record
- **THEN** the player is shown as `[Deleted Player]` and their historical ratings and game participation remain visible

#### Scenario: Replay decrypts deleted player gracefully
- **WHEN** the projection rebuilds and encounters a deleted player's event
- **THEN** the projection uses `[Deleted Player]` for name and nil for email without raising an error

### Requirement: Player can edit their own profile (GDPR Art. 16)
A player SHALL be able to update their own name and email address. Name changes SHALL emit a `PlayerUpdated` event with the new name re-encrypted using the player's existing key. Email changes SHALL require re-verification: a magic link is sent to the new email address; until confirmed, the old email remains active. On confirmation a `PlayerEmailChanged` event is emitted and the new email is encrypted and stored.

#### Scenario: Player updates their name
- **WHEN** a player submits a new name in their profile settings
- **THEN** a `PlayerUpdated` event is emitted with the updated encrypted name and the change is reflected immediately

#### Scenario: Player initiates email change
- **WHEN** a player submits a new email address in their profile settings
- **THEN** a verification magic link is sent to the new address; the old email remains active until confirmed

#### Scenario: Player confirms new email
- **WHEN** a player clicks the verification link sent to their new email address
- **THEN** a `PlayerEmailChanged` event is emitted, the new email is encrypted and stored, and the old email is no longer valid for login

#### Scenario: Unconfirmed email change does not affect login
- **WHEN** a player has initiated an email change but not yet confirmed it
- **THEN** the player can still log in with their original email address

### Requirement: Pending players are visible and manageable in the admin panel
The tenant admin panel SHALL show a list of players who have been invited but have not yet activated their account. For each pending player the admin SHALL be able to resend the magic link or delete the invitation.

#### Scenario: Admin views pending players
- **WHEN** a tenant admin opens the player management section
- **THEN** invited but not yet activated players are listed separately with their invite date

#### Scenario: Admin resends magic link to pending player
- **WHEN** a tenant admin clicks "Resend invite" for a pending player
- **THEN** a new magic link is sent to that player's email and the previous link is invalidated

#### Scenario: Admin deletes a pending invitation
- **WHEN** a tenant admin deletes a pending player invitation
- **THEN** the invitation is removed and the player cannot activate using any previously sent link

### Requirement: Pending invitations are automatically cleaned up on expiry
When a direct player invitation or invite link registration expires without activation, the pending player record SHALL be automatically deleted. If `notify_admin_on_invite_expiry` is enabled for the tenant, all tenant admins SHALL be notified by email.

#### Scenario: Expired invitation is auto-deleted
- **WHEN** a player invitation reaches its expiry without activation
- **THEN** an Oban job deletes the pending player record and invalidates any associated magic link tokens

#### Scenario: Admin notified of expired invitation (when configured)
- **WHEN** a pending invitation expires and `notify_admin_on_invite_expiry` is true
- **THEN** all tenant admins receive an email identifying the expired invitation

#### Scenario: Admin not notified when notification is disabled
- **WHEN** a pending invitation expires and `notify_admin_on_invite_expiry` is false
- **THEN** the cleanup occurs silently with no email sent

### Requirement: A player can delete their own account (GDPR Art. 17)
Any authenticated player SHALL be able to initiate deletion of their own account from their profile settings page. Self-deletion SHALL follow the identical crypto-shredding flow as admin-initiated deletion: key deleted, audit entry written, sessions revoked, magic link tokens cleared. A confirmation dialog SHALL be presented before the deletion is executed. After deletion, the player is logged out and redirected to the login page.

#### Scenario: Player self-deletes their account
- **WHEN** a player confirms account deletion in their profile settings
- **THEN** a `PlayerDeleted` event is emitted, the encryption key is deleted, all sessions are revoked, and the player is redirected to the login page

#### Scenario: Self-deletion requires confirmation
- **WHEN** a player clicks "Delete my account"
- **THEN** a confirmation dialog is shown explaining the action is irreversible before the deletion proceeds

#### Scenario: Deleted player cannot log in
- **WHEN** a formerly self-deleted player attempts to request a magic link with their old email
- **THEN** no magic link is sent (the email is no longer in active players)

### Requirement: GDPR key deletion is auditable
The system SHALL maintain a GDPR audit log recording the player_id, tenant_id, and UTC timestamp for every encryption key deletion.

#### Scenario: Key deletion is logged
- **WHEN** a player's encryption key is deleted
- **THEN** an entry is inserted into the GDPR audit log with player_id, tenant_id, and deleted_at timestamp
