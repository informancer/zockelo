## ADDED Requirements

### Requirement: Tenant isolation is enforced at the routing layer
Tenant-scoped routes are divided into two categories with different access rules:

**Public routes** — accessible to any visitor regardless of authentication or tenant membership:
- `/:tenant_slug/login`
- `/:tenant_slug/join` (invite link self-registration)
- `/:tenant_slug/imprint`
- `/:tenant_slug/privacy`

These routes reveal that a tenant exists at the given slug, which is intentional — tenant slugs are shareable by design (used in invite links, shared with players, etc.).

**Protected routes** — all other tenant-scoped routes (`/:tenant_slug/`, `/:tenant_slug/games`, `/:tenant_slug/players/*`, `/:tenant_slug/admin`, etc.) — SHALL be validated by a plug that confirms the authenticated player is a member of the tenant identified by the slug. Access by a player who is not a member of that tenant SHALL be denied with a 404, regardless of role.

An authenticated player who is a member of **both** tenant A and tenant B can access protected routes in either tenant.

#### Scenario: Unauthenticated visitor sees login page for any tenant
- **WHEN** an unauthenticated visitor accesses `/:tenant_slug/login`
- **THEN** the login page is rendered; tenant existence is neither confirmed nor denied beyond what the page itself shows

#### Scenario: Authenticated player from tenant A sees login page for tenant B
- **WHEN** an authenticated player from tenant A accesses `/:tenant_b_slug/login`
- **THEN** the login page for tenant B is rendered; they may log in if they have an account there

#### Scenario: Authenticated player from tenant A cannot access tenant B protected routes
- **WHEN** an authenticated player who is only a member of tenant A requests a protected URL under `/:tenant_b_slug/`
- **THEN** the system returns a 404

#### Scenario: Player who is a member of both tenants can access both
- **WHEN** an authenticated player who is a member of both tenant A and tenant B accesses `/:tenant_b_slug/`
- **THEN** access is granted and the tenant B dashboard is rendered

#### Scenario: Super admin can access any tenant's admin panel
- **WHEN** a super admin accesses `/admin` or any tenant's protected routes
- **THEN** access is granted; super admins are explicitly exempt from tenant membership checks

### Requirement: All resource lookups are scoped to the authenticated tenant
Every database query for games, players, and ratings SHALL include the authenticated tenant's ID as a filter condition. It SHALL be impossible to access a resource from another tenant by manipulating a UUID in the URL.

#### Scenario: IDOR attempt rejected
- **WHEN** a player manipulates a game_id or player_id in the URL to reference a resource from a different tenant
- **THEN** the query returns no result and the system renders a 404

### Requirement: Magic link and invite token generation uses cryptographically secure randomness
All tokens (magic links, invite links, session tokens) SHALL be generated using `:crypto.strong_rand_bytes/1` with at least 32 bytes of entropy, then Base64URL-encoded. Tokens SHALL be stored as their SHA-256 hash, never in plaintext.

#### Scenario: Magic link token is not stored in plaintext
- **WHEN** a magic link is generated
- **THEN** only the SHA-256 hash of the token is stored in the database; the plaintext token appears only in the email

#### Scenario: Token has sufficient entropy
- **WHEN** any token is generated
- **THEN** it is derived from at least 32 bytes of cryptographically secure random data

### Requirement: Rate limiting protects authentication endpoints
The system SHALL enforce rate limits on authentication-related actions using `Hammer`. Limits SHALL apply per IP address and per email address independently.

Rate limits:
- Magic link request: 5 per email per 10 minutes; 20 per IP per 10 minutes
- Invite link registration: 10 per IP per hour
- Magic link verification attempts: 10 per IP per 10 minutes

#### Scenario: Excessive magic link requests are rejected
- **WHEN** more than 5 magic link requests are made for the same email within 10 minutes
- **THEN** subsequent requests return a generic "check your email" response without sending a new email

#### Scenario: Rate limit error does not reveal whether email is registered
- **WHEN** a rate limit is hit on the magic link endpoint
- **THEN** the response is identical to a successful request (no enumeration possible)

### Requirement: HTTP security headers are set on all responses
The system SHALL set the following security headers on all HTTP responses via a dedicated plug:

- `Strict-Transport-Security: max-age=31536000; includeSubDomains` (HTTPS enforcement)
- `Content-Security-Policy` with the following directives (restrict resource origins):
  - `default-src 'self'`
  - `script-src 'self' 'nonce-{csp_nonce}'` — nonce generated per-request by Phoenix via `put_secure_browser_headers/2`; applied to the LiveView client script tag and JS hook bundles (Chart.js, LocalTime hook)
  - `style-src 'self' 'nonce-{csp_nonce}'`
  - `connect-src 'self' wss://{effective_host}` — required for the LiveView WebSocket connection; `effective_host` is the tenant's `custom_domain` if set, otherwise `PHX_HOST`; evaluated per request
  - `img-src 'self' data:` — permits inline SVG data URIs used by the foosball table component
  - `font-src 'self'`
- `X-Frame-Options: DENY` (clickjacking prevention)
- `X-Content-Type-Options: nosniff` (MIME type sniffing prevention)
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: camera=(), microphone=(), geolocation=()` (disable unused browser APIs)

#### Scenario: Security headers present on all responses
- **WHEN** any HTTP response is returned by the application
- **THEN** all required security headers are present

### Requirement: Session cookies use secure attributes
Session cookies SHALL be set with `HttpOnly`, `Secure`, and `SameSite=Lax` flags. The session ID SHALL be regenerated on every successful login to prevent session fixation. Sessions SHALL expire after a configurable idle period (default: 8 hours) AND an absolute maximum lifetime (default: 7 days), whichever comes first. Both durations SHALL be documented in the privacy notice.

#### Scenario: Session ID regenerated on login
- **WHEN** a player successfully authenticates via magic link
- **THEN** a new session ID is issued, invalidating any pre-login session

#### Scenario: Session cookie has secure attributes
- **WHEN** a session cookie is set
- **THEN** it includes HttpOnly, Secure, and SameSite=Lax attributes

#### Scenario: Idle session expires
- **WHEN** a session has been idle for longer than the configured timeout

#### Scenario: Session expires at absolute maximum regardless of activity
- **WHEN** a session has been active for longer than 7 days without re-authentication
- **THEN** the session is invalidated and the player must authenticate again via magic link
- **THEN** the session is invalidated and the player is redirected to login

### Requirement: Sensitive admin actions are recorded in an audit log
All security-sensitive admin actions SHALL be written to an `admin_audit_log` table. Each entry SHALL contain: actor_id, actor_role, tenant_id (if applicable), action, target_id, target_type, performed_at (UTC).

Actions to log:
- Player deleted
- Player role granted / revoked
- Tenant admin role granted / revoked
- Super admin role granted / revoked
- Tenant created / deleted
- Tenant config changed
- Invite link rotated
- GDPR data export downloaded

#### Scenario: Player deletion is logged
- **WHEN** a tenant admin or super admin deletes a player
- **THEN** an entry is written to `admin_audit_log` with the actor, target player_id, and timestamp

#### Scenario: Super admin role grant is logged
- **WHEN** a super admin grants the super admin role to another user
- **THEN** an entry is written to `admin_audit_log` with the actor, target user_id, and timestamp

### Requirement: Sensitive data is never logged
The application SHALL NOT log PII (names, emails), encryption keys, session tokens, or magic link tokens at any log level. Logging of request parameters SHALL be disabled or sanitized.

#### Scenario: Magic link token does not appear in logs
- **WHEN** a magic link is generated or verified
- **THEN** the plaintext token value does not appear in any application log output

### Requirement: CSRF protection is enforced on all state-changing requests
The application SHALL use Phoenix's built-in CSRF protection (`Plug.CSRFProtection` via `protect_from_forgery`) in the browser pipeline. All HTML form submissions and non-GET requests from browser clients SHALL include a valid CSRF token. The `/unsubscribe` endpoint is explicitly exempt as it is a tokenized, one-click action authenticated by its HMAC parameter rather than a session.

#### Scenario: Form submission without CSRF token is rejected
- **WHEN** a browser submits a POST form without a valid CSRF token
- **THEN** the server returns a 403 and the action is not performed

### Requirement: Search engine crawling is blocked
The application SHALL serve a `robots.txt` file at `GET /robots.txt` that disallows all crawlers from all paths. As a self-hosted internal tool, no content should be indexed by search engines.

#### Scenario: Crawler respects robots.txt
- **WHEN** a search engine crawler fetches `/robots.txt`
- **THEN** the response contains `User-agent: *` and `Disallow: /`

### Requirement: Role changes take effect on the next request
When a player's role is granted or revoked, the change SHALL take effect on their next authenticated request — not at session expiry. The authentication plug SHALL re-fetch the player's current role from the database on every request rather than reading it from session state. Session state SHALL contain only the player ID; roles SHALL always be resolved live.

#### Scenario: Revoked admin cannot access admin panel on their next request
- **WHEN** a tenant admin's role is revoked and they make any subsequent request
- **THEN** the admin panel is inaccessible and they are treated as a regular player regardless of their current session

#### Scenario: Newly granted admin can access admin panel immediately
- **WHEN** a player is granted the tenant admin role and makes their next request
- **THEN** they have immediate access to the admin panel without needing to log out and back in

### Requirement: Token hash comparisons use constant-time equality
All comparisons of token hashes (magic link tokens, session tokens, invite tokens) SHALL use a constant-time comparison function (`:crypto.hash_equals/2`) rather than the standard `==` operator. This prevents timing side-channel attacks that could allow an attacker to enumerate valid tokens.

#### Scenario: Token verification uses constant-time comparison
- **WHEN** an incoming token hash is compared against the stored hash
- **THEN** the comparison uses `:crypto.hash_equals/2` and returns in constant time regardless of where the hash differs

### Requirement: Ecto changesets explicitly whitelist all accepted fields
Every Ecto changeset used to process user input SHALL pass an explicit list of permitted fields to `cast/3`. Fields that must never come from user input — including `role`, `tenant_id`, `player_id`, `inserted_at`, `updated_at` — SHALL NOT appear in the cast list. This prevents mass assignment attacks where an attacker injects extra fields into a form or API request.

#### Scenario: Role field cannot be set via user-controlled input
- **WHEN** a user submits a form or request body containing a `role` field
- **THEN** the field is ignored because it is not in the changeset's cast list

### Requirement: Email header injection is prevented
All player-supplied email addresses and display names used in email headers (`From`, `Reply-To`, `To`) SHALL be validated to contain no CRLF characters (`\r`, `\n`) or other header-delimiter sequences before being passed to the email library. Any value containing such characters SHALL be rejected with a validation error at the changeset level.

#### Scenario: Email address containing CRLF is rejected
- **WHEN** a player attempts to save an email address containing a carriage return or newline character
- **THEN** the changeset validation fails and the value is not stored or used in any email header

### Requirement: Phoenix development routes are not accessible in production
Development-only routes — including Phoenix LiveDashboard (`/dev/dashboard`), the Swoosh mailbox preview (`/dev/mailbox`), and any other routes gated by `Mix.env() == :dev` — SHALL NOT be mounted in the router in the production environment. The router SHALL gate these routes explicitly on the Mix environment.

#### Scenario: LiveDashboard not accessible in production
- **WHEN** a request is made to `/dev/dashboard` in a production deployment
- **THEN** the route does not exist and the server returns a 404

### Requirement: Magic link redirect target is validated as same-origin
When a magic link includes a `return_to` query parameter, the redirect target SHALL be validated as a relative path before use. Any `return_to` value that is an absolute URL, contains a protocol, or starts with `//` SHALL be discarded and the player redirected to the tenant dashboard instead. This prevents open redirect attacks using magic links as a phishing vector.

#### Scenario: Relative return_to is honoured
- **WHEN** a magic link includes `return_to=%2Facme%2Fgames`
- **THEN** after successful authentication the player is redirected to `/:tenant_slug/games`

#### Scenario: Absolute URL in return_to is discarded
- **WHEN** a magic link includes `return_to=https://evil.example.com`
- **THEN** the redirect target is ignored and the player is sent to the tenant dashboard

### Requirement: Proxy header trust is opt-in via environment variable
`Plug.RewriteOn` (which causes the application to trust `X-Forwarded-Host`, `X-Forwarded-Proto`, and related headers) SHALL only be enabled when the environment variable `TRUST_PROXY_HEADERS=true` is set. When this variable is absent or false, the application SHALL ignore forwarded headers and use the raw request host and protocol.

This prevents an attacker who can reach the application directly (bypassing the proxy) from spoofing the `X-Forwarded-Host` header to impersonate a different tenant's custom domain. Operators using a reverse proxy (Caddy) MUST set `TRUST_PROXY_HEADERS=true`; operators exposing the application directly MUST NOT.

The `.env.example` file SHALL document this variable and note that it must be `true` when running behind Caddy or any reverse proxy.

#### Scenario: Forwarded headers ignored without opt-in
- **WHEN** `TRUST_PROXY_HEADERS` is not set and a request arrives with an `X-Forwarded-Host` header
- **THEN** the application uses the raw request host and ignores the forwarded header

#### Scenario: Forwarded headers trusted when opt-in is set
- **WHEN** `TRUST_PROXY_HEADERS=true` is set and a request arrives via Caddy with `X-Forwarded-Host: foosball.acme.com`
- **THEN** the application uses `foosball.acme.com` as the effective host for URL generation and CSP

### Requirement: HTTPS is enforced in production
The application SHALL redirect all HTTP requests to HTTPS in production. The `Secure` cookie flag SHALL only be set when the connection is HTTPS. Local development MAY use HTTP.

#### Scenario: HTTP request redirected to HTTPS in production
- **WHEN** a request arrives over HTTP in a production environment
- **THEN** the application responds with a 301 redirect to the HTTPS equivalent URL
