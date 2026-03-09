## 1. Project Setup

- [x] 1.1 Create new Phoenix project with `mix phx.new zockelo` and configure Postgres; `LICENSE` file already exists in the repo — do not overwrite it; extend the generated `.gitignore` to also exclude `.env`, `.env.*.local`, `*.secret.exs`, `priv/static/fonts/` (vendored fonts are downloaded at build time, not committed), and any editor/OS artefacts (`.DS_Store`, `.idea/`, `*.swp`)
- [x] 1.2 Add dependencies: `commanded`, `commanded_eventstore_adapter`, `eventstore`, `cloak`, `cloak_ecto`, `oban`, `gettext`, `gen_smtp` (Swoosh SMTP adapter), `ex_doc` (dev/docs only), `earmark`, `html_sanitize_ex`, `sobelow` (dev/test), `mix_audit` (dev)
- [x] 1.3 Configure EventStore (Postgres adapter) and run `mix event_store.create && mix event_store.init`
- [x] 1.4 Configure Cloak with master key from environment variable and set up `Zockelo.Vault`
- [x] 1.5 Configure Oban with three named queues: `notifications` (concurrency: 10), `scheduled` (concurrency: 5), `critical` (concurrency: 2); assign all workers to their respective queues per observability spec
- [x] 1.6 Set up PWA manifest and service worker for Android installability; generate manifest dynamically per tenant using `app_name` for `name` and `short_name`; add `<meta name="apple-mobile-web-app-title">` to layout using `app_name`; version service worker with build hash, implement `skipWaiting`, show reload banner on new version activation
- [x] 1.7 Add `hammer` dependency for rate limiting; add `chart.js` as a JS asset for rating charts; download and vendor Inter font files (`woff2`) into `priv/static/fonts/`; add `@font-face` declarations in CSS (no external font requests)
- [x] 1.8 Implement `LocalTime` LiveView JS hook: on mount, replace inner text of elements with `data-timestamp` (ISO 8601 UTC) using `Intl.DateTimeFormat` in the browser's local timezone; apply to all game timestamps, profile activity dates, and admin audit log entries
- [x] 1.9 Define CSS custom property token sets for light and dark themes (colours, surfaces, text, borders, accents); apply `prefers-color-scheme` media query as default; implement manual theme toggle in nav (stores choice in `localStorage`); sync toggle state with `player_profiles.theme` preference for authenticated users
- [x] 1.10 Design and produce app icon (icon + wordmark SVG for header; icon-only SVG/PNG set for favicon and PWA manifest icons at 192px and 512px)
- [x] 1.11 Add `.tool-versions` (asdf) or `.mise.toml` (mise) file pinning Elixir 1.18 / OTP 27 matching the Dockerfile base image; ensures local dev environment matches CI and production
- [x] 1.11a Add `docker-compose.dev.yml` for local development: single `postgres:16-alpine` service with two databases (`zockelo_dev` for Ecto, `zockelo_eventstore_dev` for EventStore), port 5432 mapped to localhost, named volume for persistence; add a `mix setup` alias in `mix.exs` that runs `cmd docker compose -f docker-compose.dev.yml up -d db`, then `ecto.setup`, then `event_store.create`, then `event_store.init`; document in `README.md` and `CONTRIBUTING.md`
- [x] 1.12 Write `README.md`: what Zockelo is, quick-start using the inspect-before-run pattern (`curl -fsSL .../setup.sh -o setup.sh` then inspect then `chmod +x && ./setup.sh`), explicit note that `curl | bash` is not recommended, link to operator guide, link to `CONTRIBUTING.md`, license badge
- [x] 1.13 Write `CONTRIBUTING.md`: dev environment setup (`mix setup`, `mix test`), how to run the app locally, coding conventions (Credo, Dialyzer, Sobelow), commit message style, PR process; include a privacy review checklist to be completed for any PR that adds or modifies data processing: (a) confirm no new PII is logged (grep new Logger calls), (b) confirm email templates contain no external URLs or tracking pixels, (c) update privacy notice if new data is collected or a new purpose introduced, (d) if a new cookie or token is added, confirm it is strictly necessary and document its TTL
- [x] 1.14 Create `CHANGELOG.md` with initial entry for v1.0.0; establish convention (e.g. Keep a Changelog format) for documenting changes between releases so operators know what changed when upgrading
- [x] 1.15 Add `.github/pull_request_template.md` (checklist: tests added, Credo passes, no PII in logs, no external email references) and `.github/ISSUE_TEMPLATE/` with bug-report and feature-request templates

## 2. Core Domain: Events and Aggregates

- [x] 2.1 Define all event structs with explicit version suffix (`TenantRegistered.V1`, `TenantRequested.V1`, `TenantApproved.V1`, `TenantRejected.V1`); establish convention: breaking event changes always introduce a new version module + `Commanded.Event.Upcaster` implementation
- [x] 2.2 Define player events: `PlayerInvited.V1`, `PlayerActivated.V1`, `PlayerDeleted.V1`
- [x] 2.3 Define game events: `GameLogged.V1`, `GameConfirmed.V1`, `GameDisputed.V1`, `GameReinstated.V1`, `GameVoided.V1`
- [x] 2.4 Implement `Tenant` aggregate with command handlers for tenant creation/approval/config update
- [x] 2.5 Implement `Player` aggregate with command handlers for invite, activate, delete
- [x] 2.6 Implement `Game` aggregate with command handlers for log, confirm, dispute, reinstate, void
- [x] 2.7 Configure Commanded application with stream-per-tenant naming (`tenant-{id}-players`, `tenant-{id}-games`)

## 3. Crypto-shredding

- [x] 3.1 Create `player_keys` Ecto migration (player_id, tenant_id, encrypted_key, created_at)
- [x] 3.2 Create `gdpr_key_deletions` Ecto migration (player_id, tenant_id, deleted_at)
- [x] 3.3 Implement key generation on `PlayerInvited` command: generate AES key, encrypt with Cloak vault, store in `player_keys`
- [x] 3.4 Implement `Zockelo.Crypto.decrypt_field/2` that returns `[Deleted Player]` / nil on key-not-found
- [x] 3.5 Implement player deletion: delete key from `player_keys`, insert into `gdpr_key_deletions`, revoke sessions, delete magic link tokens

## 4. Read Models and Projections

- [x] 4.1 Create Ecto migrations for read models: `player_ratings`, `games`, `game_rounds`, `player_profiles`, `tenants`; include all required indexes in the same migrations: (tenant_id, rating DESC) on player_ratings; (tenant_id, logged_at DESC) and (tenant_id, game_id) on games; position column indexes on game_rounds; token_hash unique indexes on sessions and magic_link_tokens; all other indexes per performance spec
- [x] 4.2 Implement `PlayerRatingsProjection`: handle `PlayerActivated` (insert with rating=1000), `GameConfirmed`/`GameLogged` (update ratings), `PlayerDeleted` (mark deleted)
- [x] 4.3 Implement Elo calculation in projection: team avg, expected score, per-player K-factor decay, delta application; apply rating floor of 100 (clamp result if below)
- [x] 4.4 Implement `GameHistoryProjection`: handle all game events, track status transitions (pending/confirmed/disputed/voided)
- [x] 4.5 Implement `TenantProjection`: handle tenant events, store config
- [x] 4.6 Add per-round rating delta tracking to `game_rounds` for player profile history

## 5. Authentication

- [x] 5.1 Create `magic_link_tokens` Ecto migration (email, token_hash, tenant_id, expires_at, used_at); expires_at set to 15 minutes from issuance
- [x] 5.2 Implement magic link generation: create token, hash for storage, send email via Swoosh; use tenant `custom_domain` as base URL when set, otherwise `PHX_HOST`; configure `Swoosh.Adapters.Local` in `config/dev.exs` (Phoenix default) so all emails are captured in memory — developers visit `http://localhost:4000/dev/mailbox` to view sent emails and click magic links without any SMTP setup
- [x] 5.3 Implement magic link verification: check hash, expiry, used_at; create session on success
- [x] 5.4 Implement session management with signed HTTP-only cookies; enforce idle timeout (default: 8 hours) AND absolute max lifetime (default: 7 days); store session `created_at` to enable absolute expiry check on each request
- [x] 5.5 Create `invite_links` Ecto migration (tenant_id, token, expires_at, created_by, revoked_at)
- [x] 5.6 Implement invite link generation, validation, and rotation for tenant admins

## 6. Authorization

- [x] 6.1 Define role system: `:super_admin`, `:tenant_admin`, `:player` with per-tenant scope
- [x] 6.2 Implement `KickerElo.Authorization.authorize/3` plug/helper for LiveView and controllers
- [x] 6.3 Protect all LiveView routes with authentication and role checks

## 7. Super Admin and Tenant Management

- [x] 7.1 Implement `Zockelo.ReleaseTasks.create_super_admin/1` function (idempotency check: no-op with warning if super admin already exists); wrap it in a `mix zockelo.create_super_admin --email <email>` mix task for dev use; both paths use the same underlying function so it is callable via `./bin/zockelo eval` in Docker release context
- [x] 7.2 Build super admin LiveView: `/admin` — tenant list, system config, super admin list; when no tenants exist show a prominent "Create your first league" call-to-action above the empty tenant list
- [x] 7.3 Build super admin tenant creation form (direct mode): slug, name, first tenant admin by email invite or existing player selection
- [x] 7.4 Build tenant request/approval flow (request form + approval queue in super admin panel); send approval/rejection emails to requester
- [x] 7.5 Build system config UI in super admin panel: `tenant_creation_mode` toggle; `audit_log_retention_days` integer input (default: 730, minimum: 90)
- [x] 7.6 Build tenant detail view in super admin panel: config, player list with roles, activity stats
- [x] 7.7 Implement super admin role grant/revoke UI with guard against removing last super admin
- [x] 7.8 Implement super admin tenant deletion (unilateral initiation, grace period, notify tenant admins)
- [x] 7.9 Add `TenantDeletionRequested`, `TenantDeletionConfirmed`, `TenantDeletionCancelled` events and aggregate handlers
- [x] 7.10 Implement `TenantDeletionWorker` Oban job: execute deletion after grace period (bulk crypto-shred all players)

## 8. Tenant Admin Panel

- [x] 8.1 Build tenant admin LiveView: `/:tenant_slug/admin` — tabbed layout: players, games, config, legal, GDPR
- [x] 8.2 Build player invite by email form (emits `PlayerInvited`, sends magic link)
- [x] 8.3 Build pending players list (invited, not activated) with resend magic link and delete actions
- [x] 8.4 Build invite link management section in admin panel: show full URL + Copy button; inline expiry date field (set or clear); Rotate button with inline confirmation prompt ("Rotate invite link? The current link will stop working immediately.") — invalidates old token, generates new one, displays new URL in place; "Generate invite link" initial state when no token exists yet; hide entire section if tenant self-registration is disabled
- [x] 8.5 Build tenant config form (rounds_to_win, points_per_round, confirmation_mode, auto_confirm_after_hours, retention_period_days, notify_admin_on_invite_expiry, default_locale, deletion_grace_period_hours, app_name, custom_domain); add DB unique index on `custom_domain`; add changeset uniqueness validation with user-facing error; add inline notice below `custom_domain` field explaining the DNS + operator Caddy steps required (always visible, not conditional)
- [x] 8.6 Build player deletion UI with confirmation step
- [x] 8.7 Build tenant admin role grant/revoke UI
- [x] 8.8 Build GDPR audit log view for tenant admins
- [x] 8.9 Build tenant deletion UI: initiation form, 4-eyes pending state, grace period countdown, cancel action
- [x] 8.10 Implement `ExpiredInviteCleanupWorker` Oban job: delete expired pending invitations, notify admins if configured

## 9. Game Logging

- [x] 9.1 Build game logging LiveView: `/:tenant_slug/games/new`
- [x] 9.2 Build SVG foosball table component with tappable front/back slots flanking each team side (red and black player figures)
- [x] 9.3 Build player card picker overlay: active (non-deleted) player cards with name + rating, search/filter input; grey out and make non-selectable any player already assigned to any slot in the current game (same team or opposing team); when a filled slot is tapped to reassign, unblock the currently assigned player first so they appear selectable again; when the tenant has ≤2 active players auto-fill both team slots on form load (picker still accessible via tap for corrections)
- [x] 9.4 Implement per-round position tracking: pre-fill round N+1 slots from round N assignments
- [x] 9.5 Implement 1v1 mode: single slot per side, no front/back distinction, no position data in event
- [x] 9.6 Implement dynamic round score inputs based on tenant `rounds_to_win` config
- [x] 9.7 Implement client-side score validation (block scores exceeding `points_per_round`)
- [x] 9.8 Implement server-side validation in `LogGame` command handler: score validation (no score exceeds `points_per_round`), winning condition validation (`rounds_to_win` must be reached), and duplicate player validation (reject if any player_id appears more than once across team1 + team2)
- [x] 9.9 Update `GameLogged` event struct to include per-round positions: `{team1_front, team1_back, team2_front, team2_back, team1_score, team2_score}`
- [x] 9.10 Update `game_rounds` read model migration to include front/back player_id columns
- [x] 9.11 Wire game logging form to dispatch `LogGame` command; add winning condition validation: disable submit until one team has won `rounds_to_win` rounds; show inline message "Keep entering rounds until a team wins" when blocked
- [x] 9.12 Implement post-submission feedback: trust mode → flash "Game logged — ratings updated", redirect to dashboard; confirmation mode → flash "Game logged — waiting for confirmation from [player names]", redirect to dashboard where pending game card is visible; store snapshot of `rounds_to_win` and `points_per_round` in `GameLogged` event at logging time

## 10. Game Confirmation Flow

- [x] 10.1 Implement `GameConfirmationWorker` Oban job: query pending games past `auto_confirm_after_hours`, dispatch `ConfirmGame` command
- [x] 10.2 Build pending games UI on leaderboard/games page (confirm/dispute buttons for participants and admins)
- [x] 10.3 Implement confirm action (dispatch `ConfirmGame` command, authorize: participant or tenant admin)
- [x] 10.4 Implement dispute action (dispatch `DisputeGame` command, authorize: participant or tenant admin)
- [x] 10.5 Build disputed games queue in tenant admin panel with reinstate/void actions
- [x] 10.6 Implement reinstate action (dispatch `ReinstateGame`, tenant admin only)
- [x] 10.7 Implement void action (dispatch `VoidGame`, tenant admin only)
- [x] 10.8 During player deletion flow, query all pending/disputed games where the deleted player is a participant and dispatch `VoidGame` for each; include in the deletion Oban job or deletion command handler
- [x] 10.9 Apply leaderboard sort order: rating DESC, games_played DESC, player_name ASC

## 11. Dashboard, Leaderboard and Player Profiles

- [x] 11.1 Build dashboard LiveView: `/:tenant_slug/` — mini leaderboard, current player stats, recent games, pending games, tenant stats, team balancer widget
- [x] 11.2 Implement team balancer algorithm: evaluate all pairings for 2/3/4 players, return fairest split with team averages and expected score
- [x] 11.3 Build team balancer widget component: toggleable player chips, suggested split display, "Log this game" button that pre-fills game logging form
- [x] 11.4 Add player filter and date-range filter to game history LiveView; reflect active filters in URL query string for bookmarkable/shareable filtered views; combine filters in Ecto query
- [x] 11.5 Build navigation components: bottom nav bar (mobile), top nav bar (desktop), user menu with admin panel link; display tenant `app_name` (fallback: "Zockelo") in nav header and page `<title>` tags
- [x] 11.6 Build leaderboard LiveView: `/:tenant_slug/leaderboard` with real-time PubSub subscription
- [x] 11.7 Publish PubSub message on ratings projection update to trigger leaderboard and dashboard refresh; use component-level assigns to push only changed player rows
- [x] 11.8 Build game history LiveView: `/:tenant_slug/games` with pagination
- [x] 11.9 Build player profile LiveView: `/:tenant_slug/players/:player_id` with rating history list and Chart.js rating line chart via LiveView JS hook (responsive, tooltip with date/opponents/rating change on tap/hover)
- [x] 11.10 Build profile settings LiveView: name/email editing, notification preferences, data export, account deletion
- [x] 11.11 Implement `PlayerUpdated` event and handler for name change (re-encrypt with existing key)
- [x] 11.12 Implement email change flow: send verification link to new email, `PlayerEmailChanged` event on confirmation
- [x] 11.13 Implement deleted player placeholder rendering (`[Deleted Player]`) across all views
- [x] 11.14 Implement GDPR data export: query profile + game history + admin_audit_log entries where player is actor_id, decrypt PII, serialize to JSON, trigger download
- [x] 11.15 Implement player self-deletion in profile settings: confirmation dialog ("this cannot be undone"), dispatch `DeletePlayer` command on confirm, follow identical crypto-shredding flow as admin deletion, log out and redirect to login page on completion
- [x] 11.16 Build root landing page LiveView (`/`): state-machine routing — (a) no super admin exists → "Getting started" page with setup instructions and release eval command; (b) super admin exists, no tenants, requesting user is super admin → redirect `/admin`; (c) super admin exists, no tenants, unauthenticated → "No leagues available yet" page; (d) tenants exist, authenticated player → redirect `/:tenant_slug/`; (e) tenants exist, authenticated super admin → redirect `/admin`; (f) tenants exist, unauthenticated → neutral "Enter your league URL" branded page with slug input that navigates to `/:slug/login` on submit; same neutral page shown regardless of how many tenants exist

## 12. In-app Help

- [x] 12.1 Build help page LiveView: `/:tenant_slug/help` — renders tenant-aware content driven by active tenant config (confirmation mode on/off, rounds to win, points per round, Elo explanation, team balancer explanation)
- [x] 12.2 Add tooltip component (accessible, keyboard-dismissable); apply to: Elo rating display, K-factor, team balancer widget, confirmation mode indicators, auto-confirm countdown

## 13. Login and Onboarding UI

- [x] 13.1 Build magic link request LiveView: `/:tenant_slug/login`
- [x] 13.2 Build "check your email" confirmation page (shown after login form submission, email-agnostic)
- [x] 13.3 Build magic link verification handler (token in URL, creates session, redirects to dashboard); for first-time activation (player never logged in before), redirect to privacy summary screen before final destination; after privacy summary: regular players → `/:tenant_slug/`; tenant admins → `/:tenant_slug/admin` with welcome banner
- [x] 13.4 Build invite link self-registration LiveView at `/:tenant_slug/join?code={token}` (name + email form, emits `PlayerInvited`); render "This invite link is no longer valid" for expired or revoked tokens
- [x] 13.5 Build privacy summary screen shown on first account activation: display brief summary of data collected (name, email, game participation), link to full privacy notice, "Continue" button; shown once only — subsequent logins skip it
- [x] 13.6 Build player activation flow (magic link from invite → `PlayerActivated` command)

## 14. Notifications

- [x] 14.1 Create `player_notification_preferences` Ecto migration (player_id, notification_type, enabled)
- [x] 14.2 Seed default preferences on `PlayerActivated` (all configurable notifications enabled by default)
- [x] 14.3 Build notification preferences UI in profile settings (toggles for each type, inactivity warning greyed out)
- [x] 14.4 Show admin notification section in preferences only for tenant admins; default admin notifications to enabled on role grant
- [x] 14.5 Implement email delivery helpers: check player preference before sending any configurable notification; set `From: {app_name} <SMTP_FROM>` for tenant-scoped emails and `Reply-To:` first tenant admin email; omit `Reply-To` for system emails (magic links, inactivity warnings); add `List-Unsubscribe` and `List-Unsubscribe-Post` headers to all configurable notification emails using HMAC token encoding `player_id:tenant_id:notification_type`
- [x] 14.6 Write email templates: game logged, game confirmed, game disputed, game auto-confirmed; use `app_name` in subject lines and email headers
- [x] 14.7 Write two distinct invitation email templates: (a) tenant admin invitation — subject "You've been invited to manage [league Name]", body explains admin access; (b) player invitation — subject "You've been invited to [league Name]"; both include league name and a single "Accept invitation" CTA linking to the magic link
- [x] 14.7 Write email templates: game disputed (admin), new player via invite link, invite expired, tenant deletion requested, system maintenance announcement; use `app_name` in subject lines and email headers
- [x] 14.8 Wire game events to notification dispatch (respect per-player preferences)
- [x] 14.9 Implement `POST /unsubscribe` endpoint (no auth, exempt from CSRF): verify HMAC-SHA256 token encoding `player_id:tenant_id:notification_type` signed with `SECRET_KEY_BASE`; on valid token disable that notification preference for the player; return 200; include `List-Unsubscribe` and `List-Unsubscribe-Post` headers on all outgoing notification emails
- [x] 14.10 Configure Oban unique jobs for all notification workers: unique key on `{worker, player_id, notification_type, trigger_id}` with a uniqueness window long enough to cover typical retry windows (e.g. 1 hour); prevents duplicate emails on job retry
- [x] 14.11 Audit all HTML email templates: remove any `<img>`, `<link>`, or `<script>` tags referencing external URLs; inline any images as base64 data URIs or remove them; add a linting note in the contributing guide prohibiting external references in email templates
- [x] 14.12 Ensure all emails are sent as multipart/alternative: every `Swoosh.Email` struct includes both `html_body` and `text_body`; write a plain-text version for each email template

## 15. Security

- [ ] 15.1 Add `hammer` dependency; implement rate limiting plug for magic link requests (per email + per IP), invite registrations, token verification
- [ ] 15.2 Implement tenant isolation plug: apply only to protected routes (all `/:tenant_slug/*` except `/login`, `/join`, `/imprint`, `/privacy`); validate that the authenticated player is a member of the tenant identified by the slug, or is a super admin; return 404 for non-members; public routes bypass the plug entirely and are accessible to any visitor regardless of authentication state
- [ ] 15.3 Enforce tenant-scoped queries: audit all Ecto queries for domain resources to ensure `tenant_id` filter is always present
- [ ] 15.4 Implement security headers plug: HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy; configure CSP with `put_secure_browser_headers/2` nonce + `connect-src wss://{effective_host}` (tenant custom_domain or PHX_HOST, resolved per request) + `img-src 'self' data:`; apply nonce to LiveView client script tag and all JS hook `<script>` tags
- [ ] 15.11 Gate `Plug.RewriteOn` behind `TRUST_PROXY_HEADERS=true` env var: only add the plug to the endpoint pipeline when `System.get_env("TRUST_PROXY_HEADERS") == "true"`; document in `.env.example` that this must be set when running behind Caddy or any reverse proxy, and must NOT be set when the application is exposed directly; add a startup warning log when the app is in production and `TRUST_PROXY_HEADERS` is not set
- [ ] 15.5 Harden session config: regenerate session ID on login, set HttpOnly + Secure + SameSite=Lax, configure idle timeout (default 8h)
- [ ] 15.6 Enforce cryptographic token generation: use `:crypto.strong_rand_bytes(32)` for all tokens; store SHA-256 hash only
- [ ] 15.7 Create `admin_audit_log` Ecto migration (actor_id, actor_role, tenant_id, action, target_id, target_type, performed_at)
- [ ] 15.8 Instrument all security-sensitive admin actions to write to `admin_audit_log`: player deletion, role changes, tenant deletion, config changes, invite rotation, data export; render unresolvable `actor_id` as `[Deleted Admin]` in all audit log views; do NOT delete audit log entries during player deletion — retention is intentional
- [ ] 15.9 Configure logger to filter PII, tokens, and keys from all log output
- [ ] 15.10 Configure HTTPS redirect and enforce Secure cookie flag in production environment config
- [ ] 15.12 Verify `Plug.CSRFProtection` is included in the browser pipeline via `protect_from_forgery`; add explicit test that POST without CSRF token returns 403; exempt `POST /unsubscribe` from CSRF (it is protected by HMAC parameter)
- [ ] 15.13 Add `priv/static/robots.txt` with `User-agent: *` / `Disallow: /`; serve it from the endpoint's static file plug
- [ ] 15.14 Implement live role resolution: authentication plug reads `player_id` from session, fetches current role from DB on every request; session stores only `player_id` — no role, no tenant membership
- [ ] 15.15 Replace all token hash comparisons with `:crypto.hash_equals/2` (magic link verification, session token lookup, invite token validation, unsubscribe HMAC check)
- [ ] 15.16 Audit every Ecto changeset that processes user input: ensure `cast/3` field lists never include `role`, `tenant_id`, `player_id`, `inserted_at`, `updated_at`, or any other privileged field; add a code-review checklist item for new changesets
- [ ] 15.17 Add changeset validation rejecting CRLF characters in all email address and display name fields; apply to player profile update, invite submission, and tenant admin email fields
- [ ] 15.18 Ensure Phoenix dev routes (`/dev/dashboard`, `/dev/mailbox`) are gated with `if Mix.env() == :dev` in the router; verify they return 404 in the test environment as a proxy for production
- [ ] 15.19 Implement `return_to` validation in the magic link verification handler: accept only relative paths (starts with `/`, no `://`, no `//`); fall back to `/:tenant_slug/` for any invalid value

## 16. Internationalisation


- [ ] 16.1 Configure Gettext with `en` and `de` locales; set English as system default
- [ ] 16.2 Implement locale resolution plug: user preference → Accept-Language header → `en` fallback
- [ ] 16.3 Add `locale` and `theme` (`light` | `dark` | `system`, default: `system`) columns to `player_profiles` read model; build locale selector and theme toggle in profile settings
- [ ] 16.4 Add `default_locale` to tenant config schema and admin form
- [ ] 16.5 Wrap all LiveView templates and components in `gettext` macros
- [ ] 16.6 Wrap all error messages and validation strings in `gettext` macros
- [ ] 16.7 Implement locale-aware email rendering: resolve locale from recipient preference → tenant default
- [ ] 16.8 Write German (de) translations for all UI strings (`priv/gettext/de/LC_MESSAGES/default.po`)
- [ ] 16.9 Write German (de) translations for all email templates
- [ ] 16.10 Translate system-generated privacy notice section into German
- [ ] 16.11 Document how to add a new locale (PO file workflow) in ops documentation

## 17. Data Retention and Cookie Compliance

- [ ] 17.1 Add `last_login_at` column to `player_profiles` read model, update on every successful magic link authentication
- [ ] 17.2 Add `retention_period_days` (default: 730) to tenant config schema and admin form
- [ ] 17.3 Implement `InactiveAccountWarningWorker` Oban job: find players within 30 days of retention threshold, send warning email
- [ ] 17.4 Implement `InactiveAccountDeletionWorker` Oban job: find players past retention threshold with elapsed warning period, trigger crypto-shredding deletion flow
- [ ] 17.5 Implement login-resets-clock: update `last_login_at` and cancel pending deletion job on successful authentication
- [ ] 17.6 Write warning email template (plain text + HTML) using relative time ("your account will be deleted in 30 days") rather than an absolute date, plus a login link
- [ ] 17.7 Add session cookie documentation to system-generated privacy notice section (name, purpose, lifetime)
- [ ] 17.8 Add self-hosted DPA note to operator documentation (README or docs/)
- [ ] 17.9 Implement `StaleRecordCleanupWorker` Oban job (daily): delete expired `magic_link_tokens`, `invite_links`, and `sessions` by `expires_at`; delete `admin_audit_log` entries older than `audit_log_retention_days` system config value

## 18. Legal Pages

- [ ] 18.1 Add imprint fields to tenant config schema (mandatory + optional fields per §5 TMG); address stored as four discrete DB columns: `street`, `postal_code`, `city`, `country_code` (ISO 3166-1 alpha-2); `country_code` is mandatory and validated; warn in admin panel separately when `country_code` is missing
- [ ] 18.2 Build imprint config form in tenant admin panel: standard text inputs for street, postal code, city; country as a dropdown (ISO 3166-1 alpha-2 list with display names); mandatory field validation warning; note under country field: "Used to pre-populate the supervisory authority in your privacy notice"
- [ ] 18.3 Build public imprint LiveView: `/:tenant_slug/imprint` (no auth required)
- [ ] 18.4 Build system-generated privacy notice LiveView: `/:tenant_slug/privacy` (no auth required), populated from imprint + fixed processing description
- [ ] 18.5 Build privacy addendum config field in tenant admin panel (Markdown input); render via `earmark` + `html_sanitize_ex` on the public privacy page
- [ ] 18.6 Add footer component with imprint and privacy links, include on all layouts including unauthenticated
- [ ] 18.7 Update system-generated privacy notice template to include: right to lodge a complaint with a supervisory authority (Art. 13(2)(d)); explicit "no third-party recipients"; explicit "no third-country transfers"; retention period shown as the actual `retention_period_days` value in days
- [ ] 18.8 Implement supervisory authority lookup module: static map of ISO 3166-1 alpha-2 country codes → `{name, url}`; covers all EU/EEA member states + `GB` (ICO); `DE` maps to BfDI with a `germany_note: true` flag so the template can render the Länder caveat; unknown or nil country returns `:unknown`; privacy notice template renders authority name+URL, Germany note, or placeholder accordingly; privacy notice derives authority live from current `country_code` — no caching

## 19. Observability and Deployment

- [ ] 19.1 Add dependencies: `prom_ex`, `logger_json`, `sentry` (GlitchTip-compatible)
- [ ] 19.2 Configure `logger_json` as the log formatter in production config
- [ ] 19.3 Implement structured log calls for: auth events, Oban failures, projection errors, admin actions
- [ ] 19.4 Configure PromEx with Phoenix, LiveView, Ecto, Oban, and VM metric groups
- [ ] 19.5 Add custom telemetry events for EventStore write/read latency; wire to PromEx
- [ ] 19.6 Implement `GET /health` endpoint: check Ecto repo + EventStore connectivity; return `{"status": "ok"}` on 200 or `{"status": "error", "reason": "database_unavailable"}` on 503; no version or build info in response; endpoint is NOT publicly accessible — Caddy blocks this path from external callers; Docker HEALTHCHECK uses `curl -f http://localhost:4000/health` inside the container; Grafana probes it via internal Docker network hostname
- [ ] 19.7 Configure GlitchTip integration via `GLITCHTIP_DSN` env var; silent no-op when unset
- [ ] 19.8 Write `docker-compose.yml` with default, `monitoring`, and `full` profiles; bind Grafana, GlitchTip, and Prometheus ports to `127.0.0.1` only (e.g. `127.0.0.1:3000:3000`); do NOT map `/metrics` or `/health` to any host port — Prometheus scrapes `/metrics` and Grafana probes `/health` container-to-container via internal Docker network only; pass `GF_SECURITY_ADMIN_PASSWORD` from env to Grafana container; pass `GLITCHTIP_SUPERUSER_EMAIL` and `GLITCHTIP_SUPERUSER_PASSWORD` from env to GlitchTip container
- [ ] 19.9 Write Grafana dashboard provisioning files (application overview, LiveView, Oban, DB, BEAM VM)
- [ ] 19.10 Write `.env.example` documenting all required and optional environment variables with descriptions (required vs optional, example values); fail-fast check in `config/runtime.exs` for missing required vars (`SECRET_KEY_BASE`, `DATABASE_URL`, `CLOAK_KEY`, `PHX_HOST`, `SMTP_HOST`, `SMTP_FROM`)
- [ ] 19.11 Write multi-stage `Dockerfile`: Elixir build stage + minimal Debian runtime stage; entrypoint executes `./bin/zockelo eval "Zockelo.Release.migrate()"` before starting the server
- [ ] 19.12 Configure `mix release` in `mix.exs`; implement `Zockelo.Release.migrate/0` module
- [ ] 19.13 Write GitHub Actions workflow (`.github/workflows/ci.yml`) following Gitflow conventions:
  - **Quality gate job** (format, credo, sobelow, audit, dialyzer, test with coverage): triggered on PRs targeting `develop` or `main`; push to `develop`, `release/**`, `hotfix/**`
  - **Publish `edge` image**: triggered on push to `develop` after quality gate passes; tags: `edge` + commit SHA
  - **Publish `latest` image**: triggered on push to `main` (Gitflow merge, quality gate already ran); tags: `latest` + commit SHA
  - **Publish versioned image**: triggered on push of `v*` tag (created by `git flow release/hotfix finish`); tags: `vX.Y.Z` + `latest` + commit SHA
  - All publish jobs authenticate to GHCR via built-in `GITHUB_TOKEN`; set package visibility to public
  - PLT cache keyed on Elixir/OTP versions for fast dialyzer runs
- [ ] 19.14 Configure ExDoc in `mix.exs` with `guides/` as extras source; write guide pages:
  - **Operator setup**: first deployment via `setup.sh`, upgrades via `setup.sh --upgrade`, version pinning, env vars, Docker profiles
  - **Observability access**: all tools (Grafana, GlitchTip, Prometheus) are bound to `127.0.0.1` and not publicly exposed; access via SSH tunnel (`ssh -L 3000:localhost:3000 user@host`); Grafana admin password is generated by `setup.sh` (no manual first-login change needed); GlitchTip admin credentials generated by `setup.sh --full` (no manual first-time setup needed); `/health` accessible only within Docker network (Caddy blocks externally); external uptime monitoring should probe `/:tenant_slug/login` instead; alternative: expose via reverse proxy subdomain with authentication (operator's responsibility)
  - **Backups**: what to back up (Postgres DB, `player_keys` table criticality, `.env`/secrets), schedule, restore, verify
  - **Security**: `CLOAK_KEY` rotation, SPF/DKIM/DMARC, Caddy reverse proxy + admin panel accessibility, ACME CA for internal networks, single-node PubSub constraint, projection rebuild
  - **Data retention schedule**: table covering all data types — magic link tokens (15 min), sessions (8 h idle / 7 days max), invite tokens (default 30 days), player data (`retention_period_days`), audit log (`audit_log_retention_days`), GDPR key deletion records (permanent), error logs in GlitchTip (operator-configured), Prometheus metrics (operator-configured)
  - **Data breach notification**: what constitutes a breach; 72-hour notification obligation to supervisory authority (Art. 33); notification to affected players if high risk (Art. 34); breach log template; links to EDPB/ICO guidance
  - **Handling data subject requests (DSARs)**: 30-day response requirement (Art. 12); identity verification; in-app export for Art. 20; directing players to in-app self-service for Art. 16/17; logging requests received
  - **GDPR legitimate interests balancing**: documented assessment for each Art. 6(1)(f) activity (game tracking, audit log retention) — necessity, proportionality, balancing statement
  - **Age and audience**: service is intended for adult workplace use; operators responsible for not enrolling users under 16; if operator's country sets a higher digital age, they must comply
  - **International data transfers**: if server is outside EU/EEA, operator may need SCCs or adequacy basis under GDPR Art. 46; operator is responsible for compliance
  - **Self-hosted DPA note**: tenant is both controller and processor — no DPA required; if ever offered as managed SaaS, Art. 28 DPA is required
  - **Tenant admin guide**, **architecture overview** (event sourcing, crypto-shredding, stream-per-tenant, event versioning)
- [ ] 19.15 Add `plug Plug.RequestId` to the endpoint (Phoenix default; confirm it is present and that `request_id` appears in all structured log entries)
- [ ] 19.18 Add `mix phx.digest` as a build step in the multi-stage Dockerfile (after `mix assets.deploy`); confirm fingerprinted assets are served with `Cache-Control: public, max-age=31536000, immutable` via `Plug.Static`
- [ ] 19.20 Write `setup.sh` standalone deployment script with two modes:
  - **Default (first install)**: check prerequisites (`docker`, `docker compose`, `curl`, `openssl`); if `docker-compose.yml` absent, download from canonical raw GitHub URL and print URL for operator verification; skip download if file already present; back up existing `.env` with timestamp; auto-generate `SECRET_KEY_BASE` (64 bytes), `CLOAK_KEY` (32 bytes), Postgres password, and `GRAFANA_ADMIN_PASSWORD` (32 bytes) via `openssl rand`; prompt for `PHX_HOST`, `SMTP_HOST`, `SMTP_FROM` (required, re-prompt on blank); prompt for optional values with defaults (`SMTP_PORT`=587, `SMTP_USERNAME`, `SMTP_PASSWORD`, `GRAFANA_ALERT_EMAIL`); numbered profile menu with RAM estimates; write `.env` with `IMAGE=ghcr.io/informancer/zockelo:latest`, commented-out blank optionals and generation timestamp; display security reminder to store secrets; offer to run `docker compose [--profile] up -d`; print the release eval command for super admin creation; if monitoring or full profile selected: wait for Grafana to become healthy, then print SSH tunnel command and generated Grafana admin credentials; if full profile selected: after GlitchTip becomes healthy, call GlitchTip HTTP API to create org + project + retrieve DSN, write `GLITCHTIP_DSN` to `.env`, restart app container; if GlitchTip API calls fail after 60-second timeout, print warning with manual instructions and continue
  - **Upgrade mode (`--upgrade`)**: download new `docker-compose.yml` (back up existing with timestamp, print diff hint); download new `.env.example` to a temp file; compare against existing `.env` and identify variables that are absent or blank; prompt for each such variable (with defaults); append absent variables, fill in blank ones; leave all non-empty values untouched; run `docker compose pull`; run `docker compose up -d` (migrations run automatically on startup); print release notes URL
  - Both modes: coloured output (green/yellow/red); idempotent; safe to re-run
- [ ] 19.19 Implement `Zockelo.Release.rotate_cloak_key/0` mix task and document the key rotation procedure in the operator guide: configure secondary key in `config/runtime.exs`, run re-encryption task, promote new key to primary, remove old key
- [ ] 19.16 Write Grafana alerting rule provisioning files (YAML): health check failure, 5xx error rate >5%, Oban failure rate >10/min, app RAM >200MB; configure contact point from `GRAFANA_ALERT_EMAIL` / `GRAFANA_WEBHOOK_URL` env vars in `docker-compose.yml`
- [ ] 19.17 Configure graceful shutdown in Mix release: set `:shutdown` timeout to 35000ms in `rel/config.exs` or `mix.exs` releases config; set `config :oban, shutdown_grace_period: 30_000`; document in operator guide that `docker stop` sends SIGTERM with a matching timeout
- [ ] 19.21 Document Caddy reverse proxy configuration in operator guide: (a) default single-domain setup — all tenants at `/{slug}/`, `/admin` at `/admin`, no special config needed; (b) per-tenant custom domain setup — complete step-by-step flow with copy-pasteable Caddy block using `rewrite * /{slug}{uri}` + `reverse_proxy app:4000 { header_up X-Forwarded-Host {host} }`; (c) DNS requirements: A record to server IP or CNAME to PHX_HOST; propagation up to 48h; (d) TLS: Caddy ACME HTTP-01 requires port 80 open; document DNS-01 alternative for restricted environments; (e) set `TRUST_PROXY_HEADERS=true` in `.env`; (f) super admin panel only accessible via `PHX_HOST/admin` — custom domain routes `/admin` to the tenant admin panel, not the super admin panel; (g) slug immutability note: if tenant slug changes, the Caddy block must be updated

## 20. Maintenance

- [ ] 20.1 Add `maintenance_message` and `maintenance_scheduled_at` fields to system config (super admin panel); clear fields to end maintenance mode
- [ ] 20.2 Build maintenance banner component: shown on all authenticated and unauthenticated pages when message is set; dismissable per session (localStorage); reappears if message changes
- [ ] 20.3 Add "maintenance announcements" as a configurable notification type in `player_notification_preferences` (default: enabled); include `List-Unsubscribe` + `List-Unsubscribe-Post` headers
- [ ] 20.4 Build maintenance email broadcast in super admin panel: sends to all active players with notification enabled; uses `app_name` in subject; includes unsubscribe link
- [ ] 20.5 Document projection rebuild procedure in operator guide: put app in maintenance mode, run `mix commanded.reset_projections`, restart app, clear maintenance message

## 21. Accessibility and Error Pages

- [ ] 21.1 Configure custom `ErrorHTML` and `ErrorJSON` modules for 404 and 500 responses; render standard application layout (with footer) but no auth required; no stack traces in production
- [ ] 21.2 Build 404 LiveView/template with link back to home page; use this response for both unknown routes and tenant isolation denials
- [ ] 21.3 Build 500 template with generic message; wire to GlitchTip capture
- [ ] 21.4 Configure Phoenix LiveView `disconnected` and `reconnecting` UI: show inline reconnecting indicator; show reload prompt after reconnect timeout
- [ ] 21.5 Make all SVG foosball table position slots focusable (`tabindex`) and activatable via Enter/Space; add ARIA labels (`aria-label="Team 1 Front — Alice, rating 1842"`)
- [ ] 21.6 Implement focus trap in player card picker overlay (focus on filter input on open, Escape closes and returns focus to triggering slot)
- [ ] 21.7 Add `aria-live="polite"` region wrapping the leaderboard table body for screen reader announcements on rating updates
- [ ] 21.8 Audit all text and interactive elements for WCAG AA colour contrast (4.5:1 minimum); ensure SVG team colours are supplemented with text labels ("Team 1", "Team 2")
- [ ] 21.9 Verify all interactive elements (buttons, nav items, position slots, player cards) meet 44×44px touch target at 375px viewport width; add CSS padding/min-size as needed
- [ ] 21.10 Run axe-core automated scan against all major pages; resolve any reported WCAG 2.1 AA violations
- [ ] 21.11 Add `:focus-visible` styles to all interactive elements (buttons, links, nav items, position slots, form inputs, toggles); ensure no `outline: none` without a visible custom replacement; verify contrast of focus ring meets 3:1 against adjacent colours (WCAG 2.4.11)
- [ ] 21.12 Wrap all CSS transitions and animations in `@media (prefers-reduced-motion: no-preference)` blocks; verify state changes are instant under `prefers-reduced-motion: reduce` (affects: theme toggle, overlay open/close, maintenance banner, PWA reload banner, LiveView diff animations)

## 22. Testing

- [ ] 22.1 Unit tests for Elo calculation (expected score, K-factor decay, delta application)
- [ ] 22.2 Unit tests for team balancer algorithm (all pairing combinations for 2/3/4 players)
- [ ] 22.3 Unit tests for score validation logic
- [ ] 22.4 Aggregate tests for `Game`, `Player`, `Tenant` (command → event assertions)
- [ ] 22.5 Projection tests for `PlayerRatingsProjection` (replay scenarios)
- [ ] 22.6 Integration tests for crypto-shredding (encrypt, delete key, verify graceful degradation)
- [ ] 22.7 Test data export: correct content, correct format, access control (player-only)
- [ ] 22.8 Integration tests for magic link flow (generate, verify, expiry, reuse)
- [ ] 22.9 LiveView tests for game logging form: score validation, winning condition gate, team picker (player greyed out after assignment; unblocked on slot reassignment; same player blocked in both same-team and opposing-team slots), slot correction, duplicate player_id rejected at backend
- [ ] 22.10 LiveView tests for confirmation flow (confirm, dispute, auto-confirm)
- [ ] 22.11 Test inactivity warning email sent at 30-day threshold
- [ ] 22.12 Test login cancels pending deletion and resets inactivity clock
- [ ] 22.13 Test imprint warning when mandatory fields missing
- [ ] 22.14 Test privacy notice renders controller identity from imprint fields
- [ ] 22.15 Test locale resolution order (preference → browser → fallback)
- [ ] 22.16 Test invite email sent in tenant default locale when no user preference exists
- [ ] 22.17 Test tenant isolation plug — protected routes: player from tenant A denied access to `/:tenant_b_slug/` and `/:tenant_b_slug/games` (returns 404); player who is a member of both tenants can access both dashboards
- [ ] 22.17b Test tenant isolation plug — public routes: authenticated player from tenant A can access `/:tenant_b_slug/login`, `/:tenant_b_slug/imprint`, `/:tenant_b_slug/privacy`, and `/:tenant_b_slug/join` without a 404; unauthenticated visitor can also access all four
- [ ] 22.18 Test IDOR prevention: tenant-scoped query returns 404 for cross-tenant resource access
- [ ] 22.19 Test rate limiting: magic link endpoint blocked after threshold per email and per IP
- [ ] 22.20 Test security headers present on all responses
- [ ] 22.21 Test session ID regenerated on login
- [ ] 22.22 Test admin audit log entries written for all security-sensitive actions
- [ ] 22.23 Verify all migrations include required indexes (review against performance spec)
- [ ] 22.24 Verify leaderboard query uses (tenant_id, rating DESC) index via EXPLAIN ANALYZE
- [ ] 22.25 Verify token lookup queries use unique indexes (magic_link_tokens, sessions)
- [ ] 22.26 Test `/health` endpoint: returns 200 with `{"status": "ok"}` when healthy; returns 503 with `{"status": "error", "reason": "database_unavailable"}` when DB unreachable; response body does NOT contain a `version` field; Caddy config test: `/health` path is not proxied externally
- [ ] 22.27 Test game history filtering: player filter, date range filter, combined filters, URL reflection
- [ ] 22.28 Test 404 page returned for unknown routes and tenant isolation denials
- [ ] 22.29 Test missing required env var causes fast fail with clear error message on startup
- [ ] 22.30 Test Chart.js hook mounts correctly and receives rating history data via LiveView assigns
- [ ] 22.31 LiveView test for help page rendering tenant-specific config (confirmation mode on/off, rounds to win)
- [ ] 22.32 Test unsubscribe HMAC token: valid token disables preference; invalid/tampered token rejected
- [ ] 22.33 Test maintenance banner shown when message set, dismissed per session, reappears on message change
- [ ] 22.34 Test event upcaster: V1 event replayed through projection produces same result as native V2 event
- [ ] 22.35 Test CSRF protection: POST to a form endpoint without a CSRF token returns 403; POST /unsubscribe without a session but with a valid HMAC token succeeds (CSRF exempt)
- [ ] 22.36 Test robots.txt: `GET /robots.txt` returns 200 with `Disallow: /` in body
- [ ] 22.37 Test Oban unique job constraint: enqueuing two notification jobs with the same `{worker, player_id, notification_type, trigger_id}` results in only one job in the queue
- [ ] 22.38 Test graceful shutdown: application process responds to SIGTERM and exits with code 0 within configured timeout
- [ ] 22.39 Test role revocation takes effect immediately: revoke tenant admin role, verify next request to admin panel returns 403/404 without re-login
- [ ] 22.40 Test role grant takes effect immediately: grant tenant admin role, verify next request to admin panel succeeds without re-login
- [ ] 22.41 Test constant-time token comparison: verify magic link and session token verification calls `:crypto.hash_equals/2` (inspect via code review or mock in unit test)
- [ ] 22.42 Test mass assignment: submit a form payload containing `role` and `tenant_id` extra fields; verify they are not applied to the record
- [ ] 22.43 Test CRLF injection rejection: submit an email address containing `\r\n`; verify changeset returns a validation error
- [ ] 22.44 Test dev routes unavailable outside dev: request `/dev/dashboard` in test env, verify 404
- [ ] 22.45 Test open redirect: verify relative `return_to` is honoured; verify absolute URL and `//host` values are discarded and redirect goes to dashboard
- [ ] 22.46 Test privacy notice includes: right to lodge supervisory authority complaint; explicit "no third-party recipients"; explicit "no third-country transfers"; `retention_period_days` rendered as a concrete number
- [ ] 22.47 Test email templates contain no external URLs: assert no `<img>`, `<link>`, or `<script>` src/href attributes reference an external domain in any generated email
- [ ] 22.48 Test `mix phx.digest` output: verify fingerprinted asset filenames exist in `priv/static/cache_manifest.json` after build
- [ ] 22.49 Test CLOAK_KEY rotation task: run re-encryption against test fixtures, verify all player keys decrypt correctly under the new key and fail gracefully under the old key after rotation
- [ ] 22.50 Test Elo rating floor: compute delta that would push rating below 100; verify result is clamped to 100
- [ ] 22.51 Test player self-deletion: player initiates deletion from profile settings; verify crypto-shredding flow executes, session is revoked, and deleted player cannot request a magic link
- [ ] 22.52 Test all email templates include both html_body and text_body (no HTML-only emails)
- [ ] 22.53 Test Oban queue assignment: verify each worker module declares the correct queue (`notifications`, `scheduled`, or `critical`)
- [ ] 22.54 Test `Zockelo.ReleaseTasks.create_super_admin/1`: creates super admin on first call; returns warning and no-ops on second call with same email
- [ ] 22.55 Test `setup.sh` first-install mode: run in a temp directory with Docker, curl, and openssl mocked; verify it downloads `docker-compose.yml` when absent and skips download when present; verify it writes a valid `.env` containing all required keys including `IMAGE=ghcr.io/informancer/zockelo:latest`; verify `SECRET_KEY_BASE` and `CLOAK_KEY` are non-empty base64 strings; verify existing `.env` is backed up before overwrite; verify it does not proceed if a required prompt is left blank
- [ ] 22.68 Test `setup.sh --upgrade` mode — absent and blank variables: run with a pre-existing `.env` containing one variable with a value, one absent variable, and one blank variable; provide a matching mock `.env.example`; verify the absent and blank variables are prompted for; verify the already-set variable is not prompted; verify `docker-compose.yml` is replaced and old one is backed up with timestamp; verify `docker compose pull` and `docker compose up -d` are called; verify no secret regeneration occurs
- [ ] 22.69 Test `setup.sh --upgrade` mode — all variables set: run with a pre-existing `.env` where every variable in the mock `.env.example` already has a non-empty value; verify the script runs fully non-interactively (no prompts); verify `docker compose pull` and `docker compose up -d` are still called
- [ ] 22.70 Test magic link token expiry: verify a token older than 15 minutes is rejected with an expiry error; verify a token within 15 minutes is accepted
- [ ] 22.71 Test session absolute max lifetime: create a session with `created_at` set to 8 days ago; verify the request is rejected and the player is redirected to login
- [ ] 22.72 Test point-of-collection privacy summary: first magic link verification for a new player renders the privacy summary screen; subsequent login for an already-activated player skips it and redirects directly to dashboard
- [ ] 22.73 Test privacy notice includes: how to exercise each right (Art. 15, 16, 17, 20, 21) with in-app instructions; Art. 18 restriction unavailability note; session cookie idle timeout and absolute max lifetime as concrete values; magic link token TTL (15 min) as a concrete value
- [ ] 22.74 Test supervisory authority lookup: `AT` → DSB name and URL; `FR` → CNIL; `DE` → BfDI with Germany note flag set; `GB` → ICO; unknown code → `:unknown`; nil → `:unknown`
- [ ] 22.75 Test privacy notice renders authority from current imprint country: set country to `NL`, render notice, verify Autoriteit Persoonsgegevens is shown; update country to `AT`, render again, verify DSB is shown — no app restart required
- [ ] 22.76 Test missing country shows placeholder in privacy notice and warning in admin panel
- [ ] 22.77 Test game logging winning condition: submit button disabled until team reaches rounds_to_win; enabled immediately when threshold is met
- [ ] 22.78 Test trust-mode submission feedback: after LogGame command, flash message "Game logged — ratings updated" is shown and player is on dashboard
- [ ] 22.79 Test confirmation-mode submission feedback: flash shows "Game logged — waiting for confirmation from [name]"; pending game card is visible on dashboard
- [ ] 22.80 Test player deletion voids pending games: delete a participant; verify all their pending games receive GameVoided event
- [ ] 22.81 Test config snapshot in GameLogged event: change rounds_to_win after logging a game; verify the stored event retains the original rounds_to_win value
- [ ] 22.82 Test invite link URL format: generated link follows /:tenant_slug/join?code={token} pattern
- [ ] 22.83 Test revoked invite link renders error page (not a 404 or crash)
- [ ] 22.91 Test invite link rotation: clicking Rotate shows confirmation prompt without invalidating the link; confirming invalidates the old token immediately and displays a new URL; old token returns "no longer valid" error; new token is valid
- [ ] 22.92 Test invite link expiry UI: setting an expiry date persists it; clearing returns to "No expiry"; link becomes invalid after expiry date passes
- [ ] 22.93 Test custom_domain uniqueness: saving a custom_domain already used by another tenant returns a validation error and does not update the record
- [ ] 22.94 Test magic link URL uses custom_domain when set; reverts to PHX_HOST after custom_domain is cleared
- [ ] 22.95 Test TRUST_PROXY_HEADERS=false (unset): X-Forwarded-Host header is ignored; application uses raw request host
- [ ] 22.96 Test TRUST_PROXY_HEADERS=true: X-Forwarded-Host header is trusted for URL generation and CSP effective_host resolution
- [ ] 22.84 Test tenant admin first login redirects to /:tenant_slug/admin after privacy summary; regular player redirects to /:tenant_slug/
- [ ] 22.85 Test leaderboard tiebreaker: two players with equal rating and equal games — sorted alphabetically; two players with equal rating, unequal games — higher games_played ranked first
- [ ] 22.86 Test player card picker auto-fill: with exactly 2 active players in tenant, form opens with both slots pre-filled; with 3+ players, slots are empty and picker must be used
- [ ] 22.87 Test tenant admin invitation email subject contains "manage"; player invitation email does not
- [ ] 22.88 Test docker-compose.yml port bindings: verify Grafana, GlitchTip, and Prometheus ports are bound to `127.0.0.1`; verify no host port mapping exists for `/metrics`; verify `GF_SECURITY_ADMIN_PASSWORD` and `GLITCHTIP_SUPERUSER_EMAIL`/`GLITCHTIP_SUPERUSER_PASSWORD` env vars are wired through from `.env`
- [ ] 22.89 Test setup.sh generates `GRAFANA_ADMIN_PASSWORD` and writes it to `.env`; verify it is 32+ bytes encoded; verify it is passed to Grafana as `GF_SECURITY_ADMIN_PASSWORD`
- [ ] 22.90 Integration test for GlitchTip API automation in setup.sh: mock GlitchTip API responses; verify org, team, project creation calls are made in order; verify DSN is written to `GLITCHTIP_DSN` in `.env`; verify non-fatal behaviour when API is unavailable (warning printed, setup continues)
- [ ] 22.56 Test audit log retention after actor deletion: delete an admin player; verify their `admin_audit_log` entries are still present with original `actor_id` intact
- [ ] 22.57 Test audit log UI renders `[Deleted Admin]` for entries whose `actor_id` no longer resolves to a player profile
- [ ] 22.58 Test GDPR data export includes `admin_audit_log` entries where the exporting player is the actor
- [ ] 22.59 Test audit log cleanup: entries older than `audit_log_retention_days` are deleted by the cleanup job; entries within the window are retained; verify minimum of 90 days is enforced on the config value
- [ ] 22.60 Test root landing page — fresh install: with no super admin in DB, GET `/` renders the "Getting started" setup instructions page containing the `./bin/zockelo eval` command
- [ ] 22.61 Test root landing page — super admin, no tenants, unauthenticated: GET `/` renders "No leagues available yet" page
- [ ] 22.62 Test root landing page — super admin, no tenants, authenticated as super admin: GET `/` redirects to `/admin`
- [ ] 22.63 Test root landing page — tenants exist, unauthenticated: GET `/` renders neutral "Enter your league URL" page with slug input, regardless of tenant count (test with 1 tenant and with 3 tenants)
- [ ] 22.64 Test root landing page — tenants exist, authenticated player: GET `/` redirects to `/:tenant_slug/`
- [ ] 22.65 Test root landing page — tenants exist, authenticated super admin: GET `/` redirects to `/admin`
- [ ] 22.66 Test neutral landing page slug submission: submitting a slug from the neutral page navigates to `/:slug/login`
- [ ] 22.67 Test CI workflow structure: verify triggers — quality gate fires on PRs to `develop`/`main` and on push to `develop`, `release/**`, `hotfix/**`; `edge` image published only on `develop` push; `latest` image published only on `main` push; versioned image published only on `v*` tag push; `GITHUB_TOKEN` used for GHCR auth; all three publish jobs apply the commit SHA tag in addition to their respective named tag
