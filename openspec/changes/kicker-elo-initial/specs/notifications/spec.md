## ADDED Requirements

### Requirement: Each player has configurable email notification preferences
Every player SHALL have a notification preferences page where they can enable or disable each configurable email notification. Preferences SHALL be stored per player. Changes take effect immediately.

The inactivity warning notification SHALL be displayed as a greyed-out, permanently enabled item with a tooltip explaining it is required for GDPR compliance and cannot be disabled.

#### Scenario: Player views notification preferences
- **WHEN** a player navigates to their profile settings → notifications
- **THEN** all configurable notifications are listed with toggle switches, and the inactivity warning is shown as greyed out and permanently on

#### Scenario: Player disables a notification
- **WHEN** a player toggles off a configurable notification
- **THEN** that notification type is no longer sent to that player

#### Scenario: Inactivity warning cannot be disabled
- **WHEN** a player attempts to disable the inactivity warning notification
- **THEN** the toggle is non-interactive and a tooltip explains it is mandatory

### Requirement: Configurable notifications for all players
The following notifications SHALL be configurable per player (default: enabled):

- **Game logged including me** *(confirmation mode only)*: sent when a game is logged that includes the player; prompts them to confirm or dispute
- **My game was confirmed**: sent when a pending game the player participated in is confirmed
- **My game was disputed**: sent when a game the player participated in is disputed
- **My game was auto-confirmed**: sent when a pending game auto-confirms after the timeout

#### Scenario: Player receives game-logged notification
- **WHEN** a game is logged in confirmation mode that includes a player who has this notification enabled
- **THEN** an email is sent to that player with game details and confirm/dispute links

#### Scenario: Notification not sent when disabled
- **WHEN** a player has disabled a notification type and a matching event occurs
- **THEN** no email is sent for that event to that player

### Requirement: Configurable notifications for tenant admins
The following notifications SHALL be configurable per tenant admin (default: enabled), shown in an additional section of the notification preferences page:

- **Game disputed in my tenant**: sent when any game in the tenant is disputed
- **New player registered via invite link**: sent when a player self-registers using the tenant invite link
- **Invite expired without activation**: sent when a pending invitation expires unaccepted (also governed by tenant-level `notify_admin_on_invite_expiry` setting)
- **Tenant deletion requested**: sent to all co-admins when a tenant deletion is initiated (requires 4-eyes confirmation)

#### Scenario: Tenant admin receives disputed game notification
- **WHEN** a game is disputed in a tenant and the admin has this notification enabled
- **THEN** an email is sent to that admin with the game details and a link to the admin panel

#### Scenario: All co-admins notified of tenant deletion request
- **WHEN** a tenant deletion is initiated by one admin
- **THEN** all other tenant admins receive a notification email regardless of their individual preferences (this notification is mandatory for the 4-eyes flow)

### Requirement: System maintenance announcements are broadcast by the super admin
The super admin SHALL be able to broadcast a maintenance announcement email to all active players across all tenants from the super admin panel. The announcement SHALL include the scheduled maintenance window and a description. Players MAY opt out of maintenance announcement emails via their notification preferences. The email SHALL include `List-Unsubscribe` and `List-Unsubscribe-Post` headers (RFC 8058).

The following notification SHALL be configurable per player (default: enabled), shown in the player notification preferences section:

- **System maintenance announcement**: sent when the super admin broadcasts a maintenance notification

#### Scenario: Super admin broadcasts maintenance announcement
- **WHEN** a super admin submits a maintenance announcement in the super admin panel
- **THEN** an email is sent to all active players who have this notification enabled, with the scheduled time and description

#### Scenario: Player opts out of maintenance announcements
- **WHEN** a player disables the maintenance announcement notification or clicks the unsubscribe link in a maintenance email
- **THEN** future maintenance announcement emails are not sent to that player

### Requirement: Invitation emails clearly state the role and league
When a `PlayerInvited` event is emitted, the activation email SHALL clearly communicate:
- The name of the league the player has been invited to (tenant `app_name` or slug)
- Whether they are being invited as a **tenant admin** or as a **regular player** — these are distinct email templates
- A single call-to-action button: "Accept invitation and set up your account" linking to the magic link URL

The **tenant admin invitation** email subject SHALL be: *"You've been invited to manage [league Name]"*
The **player invitation** email subject SHALL be: *"You've been invited to [league Name]"*

Neither template is configurable per player (these are mandatory activation emails).

#### Scenario: Tenant admin receives role-specific invitation email
- **WHEN** a `PlayerInvited` event is emitted with the tenant admin role
- **THEN** the email subject says "You've been invited to manage [league Name]" and the body explains they will have administrative access

#### Scenario: Player receives standard invitation email
- **WHEN** a `PlayerInvited` event is emitted without admin role
- **THEN** the email subject says "You've been invited to [league Name]" with no mention of admin access

### Requirement: Mandatory notifications cannot be disabled
The following notifications SHALL always be sent regardless of player preferences:

- **Inactivity warning**: required for GDPR retention compliance
- **Tenant deletion co-admin notification**: required for 4-eyes flow integrity
- **Magic link / authentication emails**: required for system access
- **Account deletion confirmation**: required for GDPR compliance

#### Scenario: Mandatory notification always delivered
- **WHEN** a mandatory notification is triggered for a player
- **THEN** the email is sent regardless of that player's notification preferences

### Requirement: All emails are sent as multipart with plain-text alternative
Every email sent by the system SHALL include both an HTML part and a `text/plain` part (multipart/alternative). The plain-text part SHALL convey the same information as the HTML part without any markup. This ensures deliverability (HTML-only emails score poorly on spam filters), accessibility (some clients and users prefer plain text), and correct rendering in plain-text-only mail clients.

#### Scenario: Email rendered in plain-text client
- **WHEN** a notification email is opened in a plain-text mail client
- **THEN** the full message content is readable without any HTML tags or encoding artefacts

### Requirement: Email templates must not include tracking pixels or external references
All HTML email templates SHALL be self-contained. They SHALL NOT include:
- Tracking pixels or web beacons (1×1 images loaded from any external server)
- External image references (`<img src="https://...">` pointing outside the deployment)
- URL tracking parameters (UTM parameters or equivalent)
- Any reference to fonts, stylesheets, or scripts hosted on external domains

All images in emails SHALL either be inline (base64 data URI) or omitted entirely. This is a strict requirement of the "privacy first" and "no external dependencies" principles; violation would cause email clients to phone home to third-party servers on email open.

#### Scenario: Email contains no external resources
- **WHEN** an HTML email is generated by the system
- **THEN** no `<img>`, `<link>`, or `<script>` tag in the email body references a URL on an external domain

### Requirement: Email notification jobs are idempotent
All Oban notification jobs SHALL use Oban's unique job feature, keyed on `{worker, player_id, notification_type, trigger_id}` (where `trigger_id` is the event ID or command ID that caused the notification). This ensures that if a job is retried after a partial failure, the player receives at most one email per trigger event.

#### Scenario: Oban retries a failed notification job
- **WHEN** a notification job fails after the email was already sent and Oban retries it
- **THEN** the unique constraint prevents a duplicate job from being enqueued; the player receives only one email

#### Scenario: Two distinct game events each trigger one email
- **WHEN** two separate `GameConfirmed` events occur for the same player
- **THEN** two separate notification emails are sent (unique constraint is per trigger_id)

### Requirement: One-click email unsubscribe is supported via RFC 8058
Emails for configurable notification types SHALL include `List-Unsubscribe` and `List-Unsubscribe-Post` headers as specified by RFC 8058. Clicking the unsubscribe link in an email SHALL open a confirmation page; submitting the `POST /unsubscribe` endpoint SHALL disable that notification type for that player in that tenant without requiring login.

The unsubscribe token SHALL be an HMAC-SHA256 value encoding `player_id:tenant_id:notification_type`, signed with the application's `SECRET_KEY_BASE`. This makes unsubscribes per-player, per-tenant, and per-notification-type. Mandatory notifications SHALL NOT include unsubscribe headers.

#### Scenario: Player clicks unsubscribe link in email
- **WHEN** a player clicks the `List-Unsubscribe` link in a notification email
- **THEN** the system renders a confirmation page showing the notification type and tenant

#### Scenario: Player confirms unsubscribe
- **WHEN** a player submits the unsubscribe confirmation (POST to `/unsubscribe`)
- **THEN** the system verifies the HMAC token, disables that notification type for that player in that tenant, and renders a success page — no login required

#### Scenario: Invalid or tampered unsubscribe token rejected
- **WHEN** a `POST /unsubscribe` request is submitted with an invalid or forged token
- **THEN** the system returns a 400 error and no preferences are changed

### Requirement: Notification preferences section is absent for non-admin players
The admin-specific notification section SHALL only be visible to users with the tenant admin role. If a player's admin role is revoked, their admin notification preferences are retained but the section is hidden.

#### Scenario: Non-admin player sees only player notifications
- **WHEN** a regular player views their notification preferences
- **THEN** only the player notification section is displayed; admin notifications are not shown

#### Scenario: Newly promoted admin sees admin notification section
- **WHEN** a player is granted the tenant admin role and views notification preferences
- **THEN** the admin notification section appears with all admin notifications defaulting to enabled
