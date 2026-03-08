## ADDED Requirements

### Requirement: Resource efficiency is a primary goal
Resource efficiency is an explicit design goal alongside security, privacy, and performance. The system SHALL minimise its deployment footprint so that the full observability stack runs comfortably on a 2GB RAM VPS. No unnecessary dependencies SHALL be introduced. Existing platform capabilities (Elixir/BEAM concurrency, Phoenix PubSub, LiveView) SHALL be preferred over adding external services.

#### Scenario: Full stack fits on a 2GB VPS
- **WHEN** the full docker-compose stack is running (app + postgres + prometheus + grafana + glitchtip + redis)
- **THEN** total RAM usage remains under 1.8GB under normal load

#### Scenario: No unnecessary dependencies added
- **WHEN** a new library or service is considered
- **THEN** it is only added if it provides functionality not achievable with existing dependencies

### Requirement: Core user-facing pages meet response time targets
The system SHALL meet the following response time targets under normal load (single tenant, up to 100 concurrent users):

| Operation                        | Target (p95) |
|----------------------------------|--------------|
| Dashboard / leaderboard load     | < 200ms      |
| Game logging form load           | < 200ms      |
| Game submit (command dispatch)   | < 500ms      |
| Magic link request               | < 300ms      |
| Magic link verification          | < 200ms      |
| Player profile load              | < 200ms      |
| Team balancer suggestion         | < 100ms      |
| Data export generation           | < 2000ms     |

#### Scenario: Dashboard loads within target
- **WHEN** an authenticated player navigates to `/:tenant_slug/`
- **THEN** the page renders within 200ms (p95) under normal load

#### Scenario: Game submit completes within target
- **WHEN** a player submits the game logging form
- **THEN** the command is dispatched and acknowledged within 500ms (p95) under normal load

#### Scenario: Magic link request completes within target
- **WHEN** a player submits the magic link request form
- **THEN** the response is returned within 300ms (p95), including token generation and email dispatch

#### Scenario: Magic link verification completes within target
- **WHEN** a player clicks a magic link and the token is verified
- **THEN** the session is created and the redirect issued within 200ms (p95)

#### Scenario: Player profile loads within target
- **WHEN** an authenticated player visits `/:tenant_slug/players/:player_id`
- **THEN** the profile with rating history renders within 200ms (p95) under normal load

#### Scenario: Data export completes within target
- **WHEN** a player requests their GDPR data export
- **THEN** the JSON file is generated and download triggered within 2000ms (p95)

#### Scenario: Team balancer responds quickly
- **WHEN** a player selects 4 players in the team balancer widget
- **THEN** the suggested split is calculated and displayed within 100ms

### Requirement: Database queries are optimised with appropriate indexes
All Ecto migrations SHALL include indexes aligned with known query patterns. Tenant-scoped queries SHALL use `tenant_id` as the leading column in composite indexes to enforce both performance and the tenant isolation guarantee at the database layer.

Required indexes:

**tenants**
- UNIQUE INDEX on `slug`
- INDEX on `status`

**player_profiles**
- INDEX on `tenant_id`
- UNIQUE INDEX on `(tenant_id, email)`
- INDEX on `last_login_at`

**player_ratings**
- UNIQUE INDEX on `player_id`
- INDEX on `(tenant_id, rating DESC)`

**games**
- UNIQUE INDEX on `(tenant_id, game_id)`
- INDEX on `(tenant_id, logged_at DESC)`
- INDEX on `logged_by`

**game_rounds**
- INDEX on `game_id`
- INDEX on `team1_front`
- INDEX on `team1_back`
- INDEX on `team2_front`
- INDEX on `team2_back`

**magic_link_tokens**
- UNIQUE INDEX on `token_hash`
- INDEX on `(email, tenant_id)`
- INDEX on `expires_at`

**invite_links**
- UNIQUE INDEX on `token`
- INDEX on `tenant_id`

**sessions**
- UNIQUE INDEX on `token_hash`
- INDEX on `player_id`
- INDEX on `expires_at`

**player_keys**
- UNIQUE INDEX on `player_id`
- INDEX on `tenant_id`

**gdpr_key_deletions**
- INDEX on `tenant_id`
- INDEX on `player_id`

**admin_audit_log**
- INDEX on `tenant_id`
- INDEX on `actor_id`
- INDEX on `performed_at`

**player_notification_preferences**
- UNIQUE INDEX on `(player_id, notification_type)`

#### Scenario: Leaderboard query uses covering index
- **WHEN** the leaderboard projection queries player ratings for a tenant
- **THEN** the query uses the `(tenant_id, rating DESC)` index and does not perform a full table scan

#### Scenario: Token lookup is O(1)
- **WHEN** a magic link or session token is verified
- **THEN** the lookup uses the `token_hash` unique index

### Requirement: LiveView assigns minimise unnecessary re-renders
LiveView components SHALL use `assign_new/3` and `update/3` appropriately to avoid re-rendering unchanged parts of the UI. Real-time leaderboard updates SHALL only push changed player rows, not the full player list.

#### Scenario: Leaderboard update pushes minimal diff
- **WHEN** a single game is confirmed and two players' ratings change
- **THEN** only the affected player rows are re-rendered in connected clients' leaderboards

### Requirement: Projection rebuilds complete in acceptable time
A full projection rebuild from the event store SHALL complete within 60 seconds for a tenant with up to 10,000 events. Full rebuilds (drop and replay) require a planned maintenance window per the maintenance spec — they cannot run safely in parallel with live traffic. Normal projection catch-up (a lagging handler replaying missed events after a restart) SHALL run in a separate process without blocking requests.

#### Scenario: Projection catch-up does not block requests
- **WHEN** a projection handler is catching up on missed events after a restart
- **THEN** the application continues serving requests using the existing read model until the handler is current

### Requirement: Stale session and token cleanup runs regularly
Expired magic link tokens, expired invite links, and expired sessions SHALL be cleaned up by a scheduled Oban job running at least once daily. Accumulation of expired records SHALL not degrade query performance.

#### Scenario: Expired tokens cleaned up regularly
- **WHEN** the cleanup job runs
- **THEN** all records with `expires_at` in the past are deleted from `magic_link_tokens`, `invite_links`, and `sessions`
