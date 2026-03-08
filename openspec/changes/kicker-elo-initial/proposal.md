## Why

Office foosball games lack a fair, persistent way to track player skill over time. Zockelo provides a self-hosted, multi-tenant Elo rating system purpose-built for foosball, giving players a live leaderboard, full game history, and meaningful ratings that evolve as they play.

## What Changes

This is a greenfield project. All capabilities are new.

- Self-hosted Phoenix LiveView web app installable as a PWA on Android
- Multi-tenant architecture with one event stream per tenant
- Individual Elo ratings for foosball players (1v1, 2v2, 2v1 formats)
- Round-level score logging with per-tenant configurable format (rounds to win, points per round)
- Rating-based K-factor decay for fair rating progression
- Event sourcing via Commanded + EventStore (Postgres) as the core architecture
- Crypto-shredding of PII for GDPR compliance (Cloak, envelope encryption)
- Magic link authentication (no passwords)
- Per-tenant configurable game confirmation with auto-confirm timeout
- Per-tenant legal pages: imprint (§5 TMG, structured fields) and system-generated GDPR privacy notice
- Two player onboarding paths: admin invite by email or shareable invite link
- Role hierarchy: super admin (system-wide), tenant admin (multiple per tenant), player
- Super admin created via `mix zockelo.create_super_admin` on first deploy

## Capabilities

### New Capabilities

- `tenancy`: Multi-tenant system management — tenant registration, approval flow (configurable: direct or request+approval), tenant config, super admin management
- `player-management`: Player lifecycle — invitation, activation, deletion with crypto-shredding, role management (tenant admin, player)
- `authentication`: Magic link auth, session management, invite link flows
- `game-logging`: Log games with round-level scores, team composition (1–2 players per side), score validation against tenant config
- `game-confirmation`: Per-tenant configurable trust-based or confirmation-based game flow — confirm, dispute, reinstate, void, auto-confirm timeout
- `elo-ratings`: Individual Elo ratings, team-avg expected score, rating-based K-factor decay, ratings projection
- `leaderboard`: Live leaderboard per tenant, player profiles with rating history, dashboard team balancer widget (fairest 2v2/2v1/1v1 suggestion from selected players)
- `gdpr-compliance`: Crypto-shredding via Cloak, GDPR key deletion audit log, deleted player anonymisation, GDPR data export (Article 20)
- `legal-pages`: Per-tenant imprint (§5 TMG) with structured fields, system-generated GDPR privacy notice (Article 13) with tenant-configurable addendum — both publicly accessible without login
- `notifications`: Per-player configurable email notifications with mandatory (non-disableable) system notifications; admin-specific notification section for tenant admins
- `i18n`: Full internationalisation via Gettext; English and German as initial languages; per-player locale preference; tenant default locale for invite emails; locale detection order: user preference → browser → English fallback
- `security`: Tenant isolation plug, IDOR prevention via tenant-scoped queries, rate limiting (Hammer), security headers, session hardening, cryptographic token storage, admin audit log, no PII in logs
- `performance`: Explicit response time targets (p95), comprehensive database index strategy with tenant_id as leading column, LiveView minimal re-renders, projection rebuild isolation, stale record cleanup; resource efficiency as explicit goal (full stack on 2GB VPS)
- `observability`: Structured JSON logging, Prometheus metrics via PromEx, pre-provisioned Grafana dashboards, GlitchTip error tracking (Sentry-compatible OSS), health check endpoint, Docker Compose deployment with monitoring/full profiles
- `accessibility`: WCAG 2.1 AA compliance — SVG foosball table keyboard navigation and ARIA labels, focus trap in player picker overlay, aria-live leaderboard updates, colour contrast enforcement, minimum 44×44px touch targets
- `error-pages`: Custom 404 (used for unknown routes and tenant isolation denials) and 500 error pages; LiveView reconnect indicator with reload prompt on persistent disconnection
- `deployment`: Multi-stage Docker image (build + minimal runtime), Mix release packaging, migration-on-startup via release eval, GitHub Actions CI/CD pipeline (format, credo, dialyzer, sobelow, audit, tests, Docker build), documented environment variables via `.env.example`
- `in-app-help`: Tenant-aware help page at `/:tenant_slug/help` explaining game rules, Elo system, and confirmation flow using the tenant's actual configured values; contextual tooltips on ratings, K-factor, team balancer, and confirmation indicators
- `maintenance`: Super admin can set a system-wide maintenance message with scheduled time; displayed as a dismissable banner on all pages; optional email broadcast to all active players (opt-out, RFC 8058 unsubscribe); projection rebuild procedure documented in operator guide; event structs explicitly versioned (`V1`, `V2`) with Commanded upcasters for schema evolution

### Modified Capabilities

None — greenfield project.

## Impact

- **New dependencies**: Elixir/Phoenix, Commanded, EventStore, Cloak/Cloak.Ecto, Postgres
- **Infrastructure**: Self-hosted, requires Postgres instance, mix task (`mix zockelo.create_super_admin`) for super admin bootstrap
- **No existing systems affected**
