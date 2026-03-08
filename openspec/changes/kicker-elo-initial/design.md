## Context

Zockelo is a greenfield self-hosted foosball Elo rating system for office use. It is built for multi-tenancy from day one, with ~20 players per tenant as the initial target. The system must support GDPR right-to-erasure while maintaining immutable event history, and must be installable as a PWA on Android devices.

## Goals / Non-Goals

**Goals:**
- Immutable event log as source of truth via Commanded + EventStore
- Per-tenant stream isolation for clean multi-tenancy
- GDPR-compliant player deletion via crypto-shredding (Cloak)
- Individual Elo ratings with rating-based K-factor decay
- Real-time leaderboard via Phoenix LiveView
- PWA support for Android home screen installation
- Magic link authentication (no passwords)
- Configurable game format and confirmation flow per tenant
- Privacy and security first: tenant isolation enforced at routing layer, rate limiting, security headers, admin audit log
- No external browser-facing dependencies: no CDN, no Google Fonts, no third-party analytics or tracking pixels; all assets served from the application itself; enforced by `default-src 'self'` CSP
- Resource efficiency: full observability stack on a 2GB VPS
- Observability: structured JSON logging, PromEx/Prometheus/Grafana, GlitchTip, health check, Docker Compose profiles

**Non-Goals:**
- Native mobile apps (iOS/Android)
- Public tournament bracket management
- Handicap correction for asymmetric team formats (2v1)
- Real-time spectator features or live score tracking during a game
- Federation between tenants or cross-tenant leaderboards

## Decisions

### 1. Event Sourcing with Commanded + EventStore

**Decision:** Use Commanded as the CQRS/ES framework backed by EventStore (Postgres adapter).

**Rationale:** The domain is naturally event-driven (games happen, ratings change, players join/leave). Event sourcing gives us full rating history replay, auditability, and the ability to recalculate ratings if the Elo algorithm changes. Commanded is the most mature ES framework in the Elixir ecosystem.

**Alternatives considered:**
- Plain Ecto with audit tables: simpler, but loses the ability to replay and recalculate ratings from scratch.
- Broadway/GenStage pipelines: too low-level for this domain.

### 2. Stream-per-tenant isolation

**Decision:** Each tenant gets its own set of named streams: `tenant-{id}-players`, `tenant-{id}-games`.

**Rationale:** Clean isolation between tenants. Enables per-tenant data export, deletion, and migration without touching other tenants' data. Stream names are prefixed by tenant ID (UUID).

**Alternatives considered:**
- Single stream with tenant_id in event metadata: simpler to start, but hard to isolate or migrate individual tenants later.

### 3. Crypto-shredding for GDPR (Cloak)

**Decision:** PII fields (name, email) in events are AES-256 encrypted with a per-player key. Keys are stored in a separate `player_keys` table, envelope-encrypted with a master key via Cloak. On player deletion, the per-player key is deleted and the deletion timestamped for audit. Events remain intact but PII becomes unreadable.

**Rationale:** Satisfies GDPR right-to-erasure without mutating the immutable event log. Per-player keys mean deletion of one player does not affect others. Envelope encryption protects keys at rest.

**Alternatives considered:**
- PII outside the event stream (separate mutable table): cleaner but means events are not self-describing; projection rebuilds require an external dependency.
- Full event deletion: violates immutability and breaks replay.

**Key store dependency:** Projection rebuilds for active players require the key store to be intact. Deleted players decrypt gracefully to `[Deleted Player]`. The key store must be backed up independently.

### 4. Ratings in projections, not in events

**Decision:** Elo calculations happen exclusively in projection handlers when processing `GameLogged` / `GameConfirmed` events. Ratings are stored in a `player_ratings` read model (Ecto). Events contain only facts (who played, what score), never derived data.

**Rationale:** Keeps the event stream as a pure factual record. Allows recalculation of all ratings by dropping and rebuilding the projection. Avoids storing derived state in the source of truth.

**K-factor decay by rating:**
```
Rating < 1400  → K = 40
1400 ≤ R < 1800 → K = 32
Rating ≥ 1800  → K = 20
```

**Elo formula:**
```
team_rating   = avg(player ratings on team)
expected      = 1 / (1 + 10^((opponent_team - our_team) / 400))
delta         = K × (actual_score - expected)   # actual: 1=win, 0=loss
each player on winning team  += delta (using their own K)
each player on losing team   -= delta (using their own K)
```

### 5. Phoenix LiveView as the frontend

**Decision:** Phoenix LiveView for all UI. No separate SPA or API layer.

**Rationale:** Keeps the stack pure Elixir. LiveView's real-time capabilities are a natural fit for live leaderboard updates. PWA support is achievable with a service worker and web manifest alongside LiveView. Reduces operational complexity.

**Alternatives considered:**
- React SPA + Phoenix JSON API: more frontend flexibility, but doubles the surface area and removes the Elixir-only advantage.

### 6. Magic link authentication

**Decision:** Auth via magic links (email-based one-time tokens). No passwords. Sessions managed with standard Phoenix session cookies.

**Rationale:** Simple, secure, and frictionless for a small office group. No password management overhead. Tokens stored in a regular Ecto table (outside the event stream) with expiry and used_at tracking.

### 7. Game confirmation flow

**Decision:** Per-tenant configurable. Two modes:
- **Trust-based:** `GameLogged` → ratings update immediately via projection.
- **Confirmation-based:** `GameLogged` → pending state. Any participant or tenant admin can confirm (`GameConfirmed`) or dispute (`GameDisputed`). Auto-confirms after a tenant-configured timeout (e.g. 24h). Tenant admins can reinstate (`GameReinstated`) or void (`GameVoided`) disputed games.

Ratings only update in the projection when a game reaches confirmed state.

### 8. Tenant creation flow

**Decision:** System-level configurable. Two modes:
- **Direct:** Super admin creates tenant and assigns first tenant admin.
- **Request + approval:** Anyone can request a tenant; super admin approves (`TenantApproved`) or rejects.

Super admin is bootstrapped via `mix zockelo.create_super_admin --email <email>` on first deploy.

### 9. Player onboarding

**Decision:** Two paths into a tenant:
1. Tenant admin invites by email → `PlayerInvited` event → magic link sent → player activates.
2. Tenant admin generates a shareable invite link (multi-use, optional expiry, rotatable) → self-registration → magic link sent → `PlayerActivated`.

Both paths converge at `PlayerActivated`.

### 10. URL structure and tenant routing

**Decision:** Tenant identified by slug in URL path: `/:tenant_slug/...`

**Rationale:** Human-readable, easy to share, no subdomain DNS complexity for self-hosting.

### 11. Observability stack

**Decision:** PromEx (Prometheus metrics) + Prometheus + Grafana + GlitchTip + structured JSON logging (`logger_json`).

**Rationale:** All components are free and open source. GlitchTip is chosen over self-hosted Sentry — it is Sentry-SDK-compatible (uses the same `sentry` hex package), significantly lighter (~300MB vs ~2GB+ for Sentry), and sufficient for this scale. PromEx integrates directly with Phoenix/Ecto/Oban telemetry with minimal configuration.

**Deployment:** Docker Compose with three profiles — default (app + postgres), monitoring (+ prometheus + grafana), full (+ glitchtip + redis). Grafana dashboards are provisioned automatically. Operators need only copy `.env.example`, fill required values, and run `docker-compose up`.

**Alternatives considered:**
- Self-hosted Sentry: too resource-heavy (~2GB RAM) for a 2GB VPS target.
- TelemetryMetricsLogger only: simpler but no dashboards or alerting.
- AppSignal/DataDog: not free/open source.

**Resource targets:**
```
Minimal (app + postgres):    ~400MB RAM
Monitoring (+ prom + grafana): ~900MB RAM
Full (+ glitchtip + redis):  ~1.8GB RAM
```

### 12. Security as a cross-cutting concern

**Decision:** Security is enforced at multiple layers rather than a single point:

- **Tenant isolation plug** — every request to `/:tenant_slug/*` validates the authenticated user belongs to that tenant before any handler runs. Returns 404 (not 403) to avoid revealing tenant existence.
- **All DB queries tenant-scoped** — every Ecto query for domain resources includes `tenant_id` as a filter condition. IDOR attacks are structurally prevented.
- **Rate limiting (Hammer)** — applied at the routing layer on authentication endpoints: magic link requests (per email + per IP), invite registrations (per IP), token verification (per IP).
- **Security headers plug** — HSTS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy applied to all responses.
- **Session hardening** — session ID regenerated on login (session fixation prevention), HttpOnly + Secure + SameSite=Lax cookie flags, configurable idle timeout (default 8h).
- **Cryptographic tokens** — all tokens generated via `:crypto.strong_rand_bytes/1` (32+ bytes), stored as SHA-256 hashes only.
- **Admin audit log** — `admin_audit_log` table records all security-sensitive admin actions with actor, target, and timestamp.
- **No sensitive data in logs** — PII, tokens, and keys are never written to application logs.

**Alternatives considered:**
- Single authorization plug checking all rules: harder to test and maintain than layered, purpose-specific plugs.
- Storing tokens in plaintext: rejected; hash storage means a DB leak does not expose valid tokens.

## Risks / Trade-offs

- **Key store as dependency for replay** → Back up `player_keys` table separately from the event store. Document this clearly in ops runbook.
- **Projection rebuild cold start** → For large event histories, rebuild can be slow. Mitigate with Commanded's snapshot support if needed (not required at initial scale).
- **Auto-confirm timing** → Implemented via Oban scheduled jobs. Failure to run means games stay pending — Oban's built-in retry and persistence handles this reliably.
- **2v1 Elo accuracy** → No handicap correction; ratings self-correct over time if one side is structurally stronger. Accepted trade-off per product decision.
- **Single Postgres instance** → No read replicas at initial scale. Acceptable for ~20 players/tenant.
- **Single-node PubSub** → PG2 adapter works only within one Erlang node. Multi-instance deployment breaks real-time leaderboard updates. Operators must not load-balance without switching to `Phoenix.PubSub.Redis`. Documented in operator guide.
- **Projection rebuild during live traffic** → Rebuild runs in a separate process using existing read model until complete. No user impact at this scale.
- **game_rounds position columns (4 indexes)** → Four separate indexes on front/back columns. Alternative: denormalise player-game participation into a separate read model for profile queries. Deferred — evaluate if query performance degrades at scale.

## Migration Plan

Greenfield — no migration required. Deployment steps:
1. Clone repo, configure environment (Postgres URL, master encryption key, `SMTP_HOST`, `SMTP_FROM`, and other vars per `.env.example`)
2. Run `mix ecto.setup` (creates DB, runs migrations)
3. Run `mix zockelo.create_super_admin --email <email>` to bootstrap super admin
4. Super admin logs in via magic link, creates first tenant, assigns tenant admin
5. Tenant admin onboards players via invite

Rollback: restore Postgres backup. No external state.

## Open Questions

All questions resolved. No open items.
