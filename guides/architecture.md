# Architecture

Zockelo is built on Elixir/Phoenix LiveView with event sourcing via Commanded + EventStore.

## Stack

| Layer | Technology |
|---|---|
| HTTP | Bandit (HTTP/2, WebSocket) |
| Web | Phoenix LiveView 1.1 (PWA) |
| Event sourcing | Commanded 1.4 + EventStore (Postgres) |
| Read models | Ecto + Postgres |
| Background jobs | Oban (three queues) |
| Auth | Magic link (no passwords) |
| Encryption | Cloak / Cloak.Ecto (AES-256-GCM) |
| Rate limiting | Hammer (ETS backend) |
| Email | Swoosh + gen_smtp |
| Metrics | PromEx → Prometheus → Grafana |
| Error tracking | Sentry protocol (GlitchTip-compatible) |

## Event Sourcing

All state changes flow through the event store. Commands are handled by aggregates,
which emit events. Event handlers (projections) update the read models.

```
Command → Aggregate → Event → EventStore
                                  ↓
                         Projection Handler
                                  ↓
                           Ecto Read Model
                                  ↓
                           LiveView Query
```

### Stream naming

Events are partitioned by tenant to prevent cross-tenant data leakage:

- `tenant-{tenant_id}-players` — player events
- `tenant-{tenant_id}-games` — game events
- `tenant-{tenant_id}-commands` — tenant commands

### Crypto-shredding

PII (email, display name) is encrypted with a per-player AES key. On player deletion,
the key is deleted, making the encrypted data irrecoverable. A `gdpr_key_deletions`
record is created for audit trail compliance.

## Multi-tenancy

Tenants are isolated at the application layer. All Ecto queries are tenant-scoped
via `tenant_id`. The `RequireTenantPlug` enforces membership — a player cannot
access another tenant's routes even if they know the slug.

## Elo Rating System

- Team average rating used for expected score calculation.
- Individual adjustments after each game.
- K-factor decays with rating: K=40 (<1400), K=32 (1400–1800), K=20 (1800+).
- Rating floor: 100 (result clamped if calculation would go below).
- Ratings live only in projections — never stored in events.

## Game Confirmation

Per-tenant configurable:

- **Trust mode**: `GameLogged` → ratings update immediately.
- **Confirmation mode**: `GameLogged` → pending → `GameConfirmed` → ratings update.
  Auto-confirms after a configurable timeout.
