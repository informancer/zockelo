## ADDED Requirements

### Requirement: Real-time features require single-node deployment or Redis-backed PubSub
The application uses `Phoenix.PubSub` with the PG2 adapter by default, which only works within a single Erlang node. Deploying multiple application instances behind a load balancer without a shared PubSub backend will cause real-time leaderboard updates and LiveView broadcasts to be delivered only to clients connected to the same node that processed the event — silently breaking the real-time experience for other users.

The operator guide SHALL document this constraint and the migration path: replacing the PG2 adapter with `Phoenix.PubSub.Redis` and adding a Redis instance to the `full` Docker Compose profile. Operators MUST NOT run multiple instances of the application without first switching to the Redis adapter.

#### Scenario: Single-node deployment — real-time updates work correctly
- **WHEN** the application runs as a single instance (default Docker Compose deployment)
- **THEN** all connected clients receive leaderboard updates via PubSub

#### Scenario: Multi-instance deployment without Redis breaks real-time
- **WHEN** multiple application instances run behind a load balancer with the default PG2 adapter
- **THEN** clients connected to a different node than the one that processed a game confirmation do not receive the leaderboard update — the operator guide SHALL warn against this configuration

### Requirement: Database migrations run automatically on deployment
The application SHALL run pending Ecto migrations automatically before starting. In the Docker deployment, the entrypoint script SHALL execute `./bin/zockelo eval "Zockelo.Release.migrate()"` before launching the application server. Migrations SHALL be idempotent and forward-only (no down migrations in production).

#### Scenario: Migrations run before app starts
- **WHEN** the Docker container starts
- **THEN** all pending migrations are applied before the application begins accepting requests

#### Scenario: App starts normally when no pending migrations exist
- **WHEN** the Docker container starts and no pending migrations exist
- **THEN** the migration step completes immediately and the app starts normally

### Requirement: Application is packaged as a Mix release
The application SHALL be built using `mix release` for production deployments. The Docker image SHALL use a multi-stage build: an Elixir build stage and a minimal Debian/Alpine runtime stage. The final image SHALL contain only the compiled release, not the Elixir toolchain.

#### Scenario: Docker image is minimal
- **WHEN** the production Docker image is built
- **THEN** the image contains only the compiled Mix release and runtime dependencies (not the Elixir/Erlang build toolchain)

### Requirement: CI/CD pipeline runs on GitHub Actions following Gitflow conventions
The repository uses the Gitflow branching model (`main`, `develop`, `feature/*`, `release/*`, `hotfix/*`). The GitHub Actions workflow SHALL be structured accordingly:

**Branches and triggers:**
- **All pull requests** targeting `develop` or `main`: run the full quality gate (steps 1–6 below)
- **Push to `develop`**: run the full quality gate + publish `edge` Docker image
- **Push to `release/*`** and **push to `hotfix/*`**: run the full quality gate (no image publish — image is published when these merge to `main`)
- **Push to `main`**: publish `latest` Docker image (quality gate already ran on the source branch)
- **Push of a `v*` tag** (created automatically by `git flow release finish` / `git flow hotfix finish`): publish versioned Docker image

**Quality gate steps (steps 1–6):**
1. Run `mix format --check-formatted`
2. Run `mix credo --strict`
3. Run `mix sobelow --exit` (Phoenix security analysis)
4. Run `mix audit` (dependency CVE scan)
5. Run `mix dialyzer` (with PLT caching)
6. Run `mix test` with coverage reporting

All steps SHALL be free using GitHub Actions' free tier for public repositories.

#### Scenario: Pull request to develop pipeline passes before merge
- **WHEN** a pull request targeting `develop` is opened
- **THEN** all quality gate steps must pass before the PR can be merged

#### Scenario: Push to develop publishes edge image
- **WHEN** a commit is pushed to `develop` and all quality gate steps pass
- **THEN** a Docker image is built and published to GHCR tagged `edge` and the commit SHA

#### Scenario: Push to main publishes production image
- **WHEN** `release/*` or `hotfix/*` is merged into `main`
- **THEN** a Docker image is built and published to GHCR tagged `latest` and the commit SHA; no quality gate re-run is required since CI already passed on the source branch

### Requirement: Docker image is published to GitHub Container Registry (GHCR)
The CI/CD pipeline SHALL publish Docker images to `ghcr.io/informancer/zockelo`. This allows operators to deploy without building from source.

**Tagging strategy:**

| Trigger | Tags applied |
|---|---|
| Push to `main` | `latest`, `<commit-sha>` |
| Push of `v*` tag (by `git flow`) | `v1.2.0`, `latest`, `<commit-sha>` |
| Push to `develop` | `edge`, `<commit-sha>` |

- **`latest`** — always points to the current production release; used by `setup.sh` and `docker-compose.yml` by default
- **`edge`** — always points to the current `develop` HEAD; intended for staging environments and preview deployments; **not suitable for production**
- **`v1.2.0`** — immutable versioned release tag; operators may pin `IMAGE=ghcr.io/informancer/zockelo:v1.2.0` in `.env` for controlled upgrades
- **`<commit-sha>`** — immutable per-build reference for full traceability on any branch

The GHCR package SHALL be public (no authentication required to pull). The CI workflow SHALL authenticate using the built-in `GITHUB_TOKEN` secret.

#### Scenario: Operator deploys without building from source
- **WHEN** an operator runs `./setup.sh` on a machine with Docker installed
- **THEN** Docker pulls `ghcr.io/informancer/zockelo:latest` automatically; no Elixir toolchain or source code is required

#### Scenario: Version tag produces a versioned image
- **WHEN** `git flow release finish v1.2.0` pushes the `v1.2.0` tag to `main`
- **THEN** the CI pipeline publishes `ghcr.io/informancer/zockelo:v1.2.0`, updates `latest`, and tags the commit SHA

#### Scenario: develop image available for staging
- **WHEN** a feature branch is merged into `develop`
- **THEN** `ghcr.io/informancer/zockelo:edge` is updated and available for staging deployment

#### Scenario: Commit SHA tag provides traceability
- **WHEN** a Docker image is pulled using a commit SHA tag
- **THEN** the exact source revision that produced the image is unambiguously identified

### Requirement: An interactive setup script guides operators through first deployment
The repository SHALL include a `setup.sh` shell script at the repository root. The script requires only `docker`, `docker compose`, `curl`, and `openssl` — no Elixir, no git, no source code required. Operators deploy using the inspect-before-run pattern:

```bash
curl -fsSL https://raw.githubusercontent.com/informancer/zockelo/main/setup.sh -o setup.sh
# inspect setup.sh before running
chmod +x setup.sh && ./setup.sh
```

This is documented as the canonical installation method in the README. The `curl | bash` pattern SHALL NOT be used or recommended.

The script SHALL be fully self-contained: if `docker-compose.yml` is not present in the current directory, `setup.sh` SHALL download it from the same release URL before proceeding. The operator does not need to clone the repository.

The script SHALL:

1. **Check prerequisites**: verify `docker`, `docker compose`, `curl`, and `openssl` are available; exit with a clear message if not
2. **Download `docker-compose.yml`** if not present: fetch from `https://raw.githubusercontent.com/informancer/zockelo/main/docker-compose.yml`; print the URL so the operator can verify the source
3. **Handle existing `.env`**: if `.env` already exists, offer to back it up (timestamped copy) before overwriting; exit gracefully if the operator declines
4. **Auto-generate secrets**: generate `SECRET_KEY_BASE` (64 random bytes, base64) and `CLOAK_KEY` (32 random bytes, base64) using `openssl rand`; generate a random Postgres password and construct `DATABASE_URL` — operators SHALL NOT need to generate these manually
5. **Prompt for required values**: `PHX_HOST` (public hostname), `SMTP_HOST`, `SMTP_FROM` — validate that each is non-empty before continuing
6. **Prompt for optional values** with defaults and skip instructions: `SMTP_PORT` (default 587), `SMTP_USERNAME`, `SMTP_PASSWORD`, `GRAFANA_ALERT_EMAIL`
7. **Choose Docker Compose profile** with a numbered menu: (1) default — app + postgres; (2) monitoring — adds prometheus + grafana; (3) full — adds glitchtip + redis; display the approximate RAM requirement for each
8. **Write `.env`**: include `IMAGE=ghcr.io/informancer/zockelo:latest`; include a generation timestamp header; comment out optional variables that were left blank
9. **Display a security reminder** to store `CLOAK_KEY` and `SECRET_KEY_BASE` in a password manager or secrets vault before proceeding
10. **Offer to start**: run `docker compose [--profile <profile>] up -d` if the operator confirms; Docker pulls `ghcr.io/informancer/zockelo:latest` automatically
11. **Print the super admin creation command** after starting:
    ```
    docker compose exec app ./bin/zockelo eval \
      'Zockelo.ReleaseTasks.create_super_admin("your@email.com")'
    ```

The script SHALL use coloured output (green for success, yellow for warnings, red for errors) and be idempotent — safe to re-run.

### Requirement: setup.sh supports an upgrade mode for updating an existing deployment
`setup.sh --upgrade` SHALL handle the full upgrade path from any previous version. It requires only `docker`, `docker compose`, `curl`, and `openssl`. The upgrade mode SHALL:

1. **Download the new `docker-compose.yml`**: fetch from the canonical URL, back up the existing file with a timestamp (e.g. `docker-compose.yml.bak-20260308-143021`), replace it, and print both the URL and a note that the operator can diff the backup against the new file
2. **Download the new `.env.example`** to a temporary file; compare it against the existing `.env`; identify variables that are either absent from `.env` or present but blank (empty value); prompt the operator for each such variable, applying defaults where available; write the values into `.env` (append new variables, fill in blank ones); leave all variables that already have a non-empty value untouched
3. **Pull the new image**: run `docker compose pull`
4. **Restart the application**: run `docker compose up -d`; the entrypoint automatically applies any new database migrations before the app starts accepting requests
5. **Print the release notes URL** for the new version so the operator can review breaking changes or manual steps

The upgrade mode SHALL NOT regenerate secrets, NOT re-prompt for already-configured variables, and NOT overwrite the existing `.env` wholesale.

#### Scenario: Operator deploys without cloning the repository
- **WHEN** an operator downloads `setup.sh` via curl, inspects it, and runs it on a machine with Docker installed
- **THEN** the script downloads `docker-compose.yml`, guides them through all prompts, writes a valid `.env`, and optionally starts the application — without requiring git, Elixir, or source code

#### Scenario: docker-compose.yml already present — not re-downloaded on fresh install
- **WHEN** an operator runs `setup.sh` (without `--upgrade`) and `docker-compose.yml` already exists in the current directory
- **THEN** the script skips the download step and uses the existing file

#### Scenario: Existing .env is backed up before overwrite
- **WHEN** an operator runs `./setup.sh` and a `.env` file already exists
- **THEN** the script offers to back up the existing file with a timestamp before overwriting

#### Scenario: Missing required field blocks progress
- **WHEN** an operator leaves a required field (PHX_HOST, SMTP_HOST, or SMTP_FROM) blank
- **THEN** the script re-prompts for that field rather than writing an invalid `.env`

#### Scenario: Upgrade prompts for absent or blank variables
- **WHEN** an operator runs `./setup.sh --upgrade` and the new `.env.example` contains a variable that is absent from or blank in the existing `.env`
- **THEN** the operator is prompted for that variable; all variables that already have a non-empty value are left untouched

#### Scenario: Upgrade with all variables already set completes non-interactively
- **WHEN** an operator runs `./setup.sh --upgrade` and every variable in `.env.example` is already present with a non-empty value in `.env`
- **THEN** the script downloads the new compose file, pulls the new image, and restarts the app without any interactive prompts

#### Scenario: Upgrade applies database migrations automatically
- **WHEN** an operator runs `./setup.sh --upgrade` and V2 includes a new database migration
- **THEN** after `docker compose up -d`, the app container runs the migration before accepting requests — no separate migration step is required

### Requirement: Super admin creation works in both development and Docker release contexts
The `mix zockelo.create_super_admin --email <email>` mix task SHALL be implemented by delegating to a `Zockelo.ReleaseTasks.create_super_admin/1` function. This function SHALL also be callable via `./bin/zockelo eval` in the Docker release, enabling super admin creation without requiring `mix` in the production container.

#### Scenario: Super admin created in Docker deployment
- **WHEN** an operator runs `docker compose exec app ./bin/zockelo eval 'Zockelo.ReleaseTasks.create_super_admin("admin@example.com")'`
- **THEN** a super admin account is created and a magic link is sent to that address

### Requirement: Environment configuration is fully documented
A `.env.example` file SHALL document every environment variable the application reads, with descriptions, whether it is required or optional, and example values. Required variables without defaults SHALL cause the application to fail fast with a clear error message on startup.

Required variables:
- `SECRET_KEY_BASE` — Phoenix session signing key
- `DATABASE_URL` — Postgres connection string
- `CLOAK_KEY` — Master encryption key (base64-encoded 32 bytes)
- `PHX_HOST` — Public hostname for URL generation
- `SMTP_HOST` — SMTP relay hostname
- `SMTP_FROM` — Sender address shown on all outgoing emails

Optional variables:
- `SMTP_PORT` — SMTP port (default: 587; use 465 for SSL, 25 for unauthenticated relay)
- `SMTP_USERNAME` — SMTP auth username (omit for unauthenticated relay)
- `SMTP_PASSWORD` — SMTP auth password (omit for unauthenticated relay)
- `GLITCHTIP_DSN` — Error tracking (silent no-op if absent)
- `PHX_PORT` — HTTP port (default: 4000)
- `POOL_SIZE` — DB connection pool size (default: 10)
- `GRAFANA_ALERT_EMAIL` — Email address for Grafana alert notifications (omit to disable email alerts)
- `GRAFANA_WEBHOOK_URL` — Webhook URL for Grafana alert notifications (omit to disable webhook alerts)

The application uses Swoosh with the SMTP adapter (`gen_smtp`) as its default email backend. Operators who prefer a different delivery provider (Mailgun, Postmark, SendGrid, etc.) may substitute the adapter in `config/runtime.exs`; the Swoosh adapter docs cover each provider's configuration. No application code changes are required to swap adapters.

#### Scenario: Missing required variable causes fast failure
- **WHEN** the application starts without a required environment variable set
- **THEN** it exits immediately with a clear error message naming the missing variable

### Requirement: Static assets are fingerprinted for cache efficiency
The production Docker build SHALL run `mix phx.digest` to generate content-hashed filenames for all static assets (CSS, JS, fonts, icons). The application SHALL serve fingerprinted assets with `Cache-Control: public, max-age=31536000, immutable` headers. This ensures users always receive the latest assets after a deploy while maximising cache hit rates between deploys.

#### Scenario: Assets served with long-lived cache headers
- **WHEN** a browser requests a fingerprinted static asset (e.g. `app-a1b2c3d4.css`)
- **THEN** the response includes `Cache-Control: public, max-age=31536000, immutable`

#### Scenario: Deploy invalidates old asset URLs
- **WHEN** a new version of the application is deployed with changed CSS
- **THEN** the new asset has a different content hash in its filename, forcing browsers to fetch it

### Requirement: Master encryption key rotation is documented
The operator guide SHALL document the procedure for rotating the Cloak master encryption key (`CLOAK_KEY`). Cloak supports multiple configured keys with a designated primary; the rotation procedure uses this to re-encrypt all per-player keys in `player_keys` under the new primary without downtime. The guide SHALL cover:
- When rotation is advisable (key suspected compromised, periodic rotation policy)
- How to configure multiple keys in `config/runtime.exs`
- How to run the re-encryption migration
- How to remove the old key once re-encryption is complete and verified

#### Scenario: Operator rotates master key without data loss
- **WHEN** an operator follows the key rotation procedure
- **THEN** all player keys are re-encrypted under the new master key and PII decryption continues to function normally

### Requirement: Backup strategy is documented and covers all critical data
The operator guide SHALL document the backup strategy for a Zockelo deployment. The following data stores require backup:

- **Postgres database** (primary backup): all application data including the event store, read models, and tenant config. Daily full backup minimum; operators may choose a tool (pg_dump, pgBackRest, Litestream-equivalent for Postgres, managed backup by hosting provider).
- **`player_keys` table** (critical): must be backed up with the same frequency as the database and stored separately from the event store backup. Loss of this table means PII in historical events becomes permanently unreadable for active players. The operator guide SHALL highlight this dependency explicitly.
- **`.env` / secrets**: encryption keys and credentials must be stored separately from the database backup (e.g. a secrets manager or offline vault).

The operator guide SHALL document:
- What to back up and why
- A minimum recommended backup schedule
- How to verify a backup (restore test)
- How to restore from backup (step-by-step)

#### Scenario: Operator follows backup documentation
- **WHEN** an operator follows the backup and restore procedure in the operator guide
- **THEN** a Zockelo deployment can be fully restored from backup to a functional state

### Requirement: Application shuts down gracefully on SIGTERM
The application SHALL handle `SIGTERM` (sent by Docker, Kubernetes, or `docker-compose stop`) with a graceful shutdown sequence:
1. Stop accepting new HTTP requests
2. Allow in-flight requests to complete (up to a configurable timeout, default: 30 seconds)
3. Allow Oban to finish in-progress jobs or checkpoint them for retry (Oban `shutdown_grace_period`: 30 seconds)
4. Close database connections cleanly

The Mix release configuration SHALL set an appropriate `:shutdown` timeout to accommodate this sequence.

#### Scenario: Running Oban job is not interrupted mid-execution on shutdown
- **WHEN** the container receives SIGTERM while an Oban job is running
- **THEN** the job is allowed to complete or checkpoint within the grace period before the process exits

#### Scenario: In-flight HTTP request completes on shutdown
- **WHEN** the container receives SIGTERM while an HTTP request is being processed
- **THEN** the request is allowed to complete before the listener is closed

### Requirement: Super admin panel is accessible regardless of custom domain configuration
When operators configure Caddy with custom domains for tenants (e.g. `foosball.acme.com` → rewrites to `/:tenant_slug/`), the super admin panel at `/admin` SHALL remain accessible.

Caddy operates as a transparent reverse proxy: it forwards all request paths to the application, including `/admin`. The path rewriting for custom domains applies only to tenant-scoped routes. `/admin` is a root-level Phoenix route and is unaffected by tenant URL rewriting in Caddy.

The operator guide SHALL document:
1. **Single-domain setup** (default): all tenants accessed at `https://{PHX_HOST}/:slug/` — `/admin` is at `https://{PHX_HOST}/admin`, no special configuration needed.
2. **Custom domain setup**: each tenant may optionally configure a `custom_domain` (e.g. `foosball.acme.com`). Caddy routes `foosball.acme.com` to the app, and the app uses the `X-Forwarded-Host` header (via `Plug.RewriteOn`) to resolve the tenant slug. The `/admin` panel is still accessible at `https://{PHX_HOST}/admin` (the base domain, not via the custom tenant domain).
3. **Operator guidance**: super admins SHOULD bookmark `https://{PHX_HOST}/admin` as the canonical admin URL. It is intentionally not exposed via tenant custom domains, which provides a natural separation between tenant-facing and admin interfaces.

#### Scenario: /admin accessible on base domain with custom tenant domain configured
- **WHEN** a tenant has `custom_domain = "foosball.acme.com"` configured and a super admin navigates to `https://{PHX_HOST}/admin`
- **THEN** the super admin panel loads correctly; the custom domain configuration does not block access to the admin panel via the base domain

#### Scenario: Caddy proxies /admin path to application
- **WHEN** Caddy receives a request for `/admin` on any configured domain
- **THEN** the request is forwarded to the Phoenix application unchanged and the application handles routing

### Requirement: Responsive SVG foosball table scales across screen sizes
The SVG foosball table component SHALL use a `viewBox` attribute and scale with CSS (`width: 100%; height: auto`) to fit any screen width. Position slots SHALL maintain a minimum touch target of 44×44px at all breakpoints. The layout SHALL be tested at 375px (iPhone SE) and 430px (large Android) widths.

#### Scenario: Table renders correctly on small screen
- **WHEN** the game logging form is viewed on a 375px-wide screen
- **THEN** the foosball table SVG fills the available width, all slots are visible and tappable, no horizontal scrolling occurs

#### Scenario: Table scales up on larger screens
- **WHEN** the game logging form is viewed on a desktop screen
- **THEN** the SVG scales proportionally with a maximum width constraint to avoid becoming too large
