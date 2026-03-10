# Operator Guide

This guide covers deploying, configuring, and maintaining a Zockelo instance.

## Quick Start (Docker)

See `README.md` for the inspect-before-run installation procedure.

```bash
curl -fsSL https://raw.githubusercontent.com/informancer/zockelo/main/setup.sh -o setup.sh
# Review the script before running it
chmod +x setup.sh
./setup.sh
```

## Environment Variables

All configuration is via environment variables in `.env`. See `.env.example` for the
full list with descriptions.

### Required Variables

| Variable | Description |
|---|---|
| `SECRET_KEY_BASE` | Phoenix secret key (64+ bytes). Generate with `mix phx.gen.secret`. |
| `DATABASE_URL` | Postgres URL for the main Ecto database. |
| `EVENT_STORE_URL` | Postgres URL for the EventStore database (separate DB, same instance is fine). |
| `CLOAK_KEY` | AES-256-GCM encryption key for PII. See Key Management. |
| `PHX_HOST` | Public hostname (e.g. `foosball.example.com`). No protocol or trailing slash. |
| `SMTP_HOST` | SMTP relay hostname for outgoing email. |
| `SMTP_FROM` | From address for all outgoing emails. |

## Caddy Reverse Proxy

Zockelo runs on port 4000 and expects to be behind a TLS-terminating reverse proxy.
Caddy is the recommended proxy because it handles ACME TLS certificates automatically.

### Default Setup (all tenants at one domain)

```caddy
foosball.example.com {
    # Block internal endpoints from external access
    @internal path /health /metrics
    respond @internal 404

    reverse_proxy localhost:4000
}
```

Set `TRUST_PROXY_HEADERS=true` in `.env` to enable forwarded header processing.

### Per-tenant Custom Domain Setup

When a tenant has a custom domain configured, their login page and public pages
are served at that domain. The super admin panel is only accessible via `PHX_HOST/admin`.

Step-by-step for adding a custom domain for tenant with slug `acme`:

1. Set `custom_domain = "kicker.acme.com"` in the tenant's admin config.
2. Create a DNS A record: `kicker.acme.com → <server IP>` (or CNAME to `foosball.example.com`).
   Allow up to 48h for propagation.
3. Add a Caddy block:

```caddy
kicker.acme.com {
    @internal path /health /metrics /admin
    respond @internal 404

    rewrite * /acme{uri}
    reverse_proxy localhost:4000 {
        header_up X-Forwarded-Host {host}
    }
}
```

**Notes:**
- TLS: Caddy uses ACME HTTP-01 by default. Port 80 must be open.
  For restricted environments, configure DNS-01 instead.
- `/admin` at a custom domain routes to the *tenant* admin panel (not super admin).
  Super admin is only accessible at `PHX_HOST/admin`.
- Slug immutability: if a tenant's slug changes, update the Caddy `rewrite` rule accordingly.
- Set `TRUST_PROXY_HEADERS=true` to trust `X-Forwarded-Host` for URL generation.

## Key Management

### Initial Setup

Generate a CLOAK_KEY:

```elixir
:crypto.strong_rand_bytes(32) |> Base.encode64() |> IO.puts()
```

Store it in `.env` as `CLOAK_KEY=<base64-encoded-value>`.

### Key Rotation

Rotating the Cloak key re-encrypts all player PII keys under a new master key.
No player data is lost; all encrypted fields are transparently re-wrapped.

1. Generate a new key and add it as a secondary cipher in `config/runtime.exs`:

   ```elixir
   config :zockelo, Zockelo.Vault,
     ciphers: [
       default: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V2", key: {:system, "CLOAK_KEY_NEW"}},
       secondary: {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: {:system, "CLOAK_KEY"}}
     ]
   ```

2. Set `CLOAK_KEY_NEW` in `.env` and deploy the updated image.

3. Run the re-encryption task inside the running container:

   ```bash
   docker compose exec app ./bin/zockelo eval "Zockelo.Release.rotate_cloak_key()"
   ```

4. Confirm all keys were re-encrypted (zero errors in output).

5. Promote the new key: rename `CLOAK_KEY_NEW` → `CLOAK_KEY` in `.env`,
   remove the `secondary` cipher config, and redeploy.

6. Optionally remove the old `CLOAK_KEY` secret from your secrets manager.

## Maintenance Mode

1. In the super admin panel (`/admin`), set a **Maintenance Message**.
   Optionally set a **Scheduled At** timestamp to show the banner in advance.
2. The banner appears on all pages (authenticated and public) immediately.
   Players can dismiss it per session; it reappears if the message changes.
3. To broadcast the maintenance via email, use **Send Maintenance Email** in the admin panel.
4. To end maintenance mode, clear the Maintenance Message field and save.

## Projection Rebuild

Use this if projections become inconsistent (e.g., after a schema change or bug fix).

1. Put the application in **Maintenance Mode** via the super admin panel.
2. SSH into the server and run:

   ```bash
   docker compose exec app ./bin/zockelo eval "Zockelo.Release.migrate()"
   ```

3. Reset projections (replays all events):

   ```bash
   docker compose exec app mix commanded.reset_projections
   ```

4. Restart the application:

   ```bash
   docker compose restart app
   ```

5. Verify the leaderboard and game history look correct.
6. Clear the Maintenance Message.

## Graceful Shutdown

The container is configured with a 35-second stop grace period. When Docker sends SIGTERM
(e.g., on `docker compose down` or rolling deploy), the application:

1. Stops accepting new connections.
2. Allows in-flight HTTP requests and LiveView sessions to drain.
3. Gives Oban workers 30 seconds to finish in-progress jobs.
4. Exits cleanly.

If you must stop immediately: `docker compose kill app` (sends SIGKILL).

## Monitoring

Start the monitoring stack:

```bash
docker compose --profile monitoring up -d
```

Grafana is available at `http://localhost:3000` (login: `admin` / `GF_SECURITY_ADMIN_PASSWORD`).
Prometheus is at `http://localhost:9090`.

Both are bound to `127.0.0.1` only and not externally accessible.

## Upgrades

```bash
./setup.sh --upgrade
```

The upgrade mode pulls the latest image and restarts the application.
Database migrations run automatically on startup.

## Backups

Back up the Postgres data volume:

```bash
docker compose exec db pg_dumpall -U zockelo > backup-$(date +%Y%m%d).sql
```

Restore:

```bash
docker compose exec -T db psql -U zockelo < backup-YYYYMMDD.sql
```
