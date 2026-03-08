## ADDED Requirements

### Requirement: Players authenticate via magic link
The system SHALL authenticate users exclusively via email magic links. No passwords SHALL be stored. A magic link token SHALL be single-use, expire after 15 minutes, and be invalidated after first use.

#### Scenario: Player requests a magic link
- **WHEN** a player submits their email on the login page for a valid tenant
- **THEN** a magic link token is generated, stored (hashed) with an expiry, and emailed to that address

#### Scenario: Player logs in via magic link
- **WHEN** a player clicks a valid, unexpired magic link
- **THEN** the token is marked as used, a session is created, and the player is redirected to the tenant leaderboard

#### Scenario: Expired magic link rejected
- **WHEN** a player clicks a magic link that has expired (>15 minutes old)
- **THEN** the system rejects the link and prompts the player to request a new one

#### Scenario: Already-used magic link rejected
- **WHEN** a player attempts to use a magic link that has already been used
- **THEN** the system rejects the link with an appropriate error message

### Requirement: Sessions are managed with secure cookies
The system SHALL use signed, HTTP-only session cookies for authentication state. Sessions SHALL expire after a configurable idle period.

#### Scenario: Authenticated player accesses protected page
- **WHEN** a player with an active session navigates to a tenant page
- **THEN** the page is rendered without requiring re-authentication

#### Scenario: Player with no session is redirected to login
- **WHEN** an unauthenticated user navigates to a protected tenant page
- **THEN** the system redirects to `/:tenant_slug/login`

### Requirement: Players can log out
The system SHALL allow players to end their session explicitly.

#### Scenario: Player logs out
- **WHEN** a player clicks the logout button
- **THEN** the session is invalidated and the player is redirected to the login page

### Requirement: Invite links allow self-registration
A tenant admin SHALL be able to generate a shareable invite link. Any user with the link SHALL be able to self-register for that tenant.

#### Scenario: Tenant admin generates invite link
- **WHEN** a tenant admin creates an invite link with optional expiry
- **THEN** a unique invite token is generated and a shareable URL is displayed

#### Scenario: User registers via invite link
- **WHEN** a user visits a valid invite link and submits their name and email
- **THEN** a `PlayerInvited` event is emitted and a magic link is sent to their email for activation

#### Scenario: Expired invite link rejected
- **WHEN** a user visits an invite link that has passed its expiry date
- **THEN** the system displays an error and does not allow registration

#### Scenario: Tenant admin rotates invite link
- **WHEN** a tenant admin rotates the invite link
- **THEN** the previous invite token is invalidated and a new token is issued
