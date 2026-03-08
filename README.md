# Zockelo

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**Zockelo** is a self-hosted foosball Elo rating tracker built for office use. It supports 1v1, 2v2, and asymmetric 2v1 games, multi-tenancy (each team or office is a separate "league"), magic-link authentication, and a full audit trail via event sourcing.

## Features

- Per-league Elo ratings with K-factor decay
- Round-level score logging, not just match results
- Game confirmation flow with auto-confirm and dispute handling
- Crypto-shredding for GDPR-compliant player deletion
- Installable PWA (Android home screen)
- Self-hosted — you control your data

## Quick Start (self-hosted)

> **Note:** We recommend the inspect-before-run pattern. Do **not** pipe `curl` directly to `bash`.

```sh
# Download and inspect the setup script first
curl -fsSL https://github.com/informancer/zockelo/releases/latest/download/setup.sh -o setup.sh
less setup.sh

# Then run it
chmod +x setup.sh
./setup.sh
```

The script will guide you through generating secrets, configuring the `.env` file, and starting the Docker containers.

For a full walkthrough including DNS setup and Caddy configuration, see the [Operator Guide](docs/operator-guide.md).

## Development Setup

Requirements: Elixir 1.18 / OTP 27 (see `.tool-versions`), Docker.

```sh
mix setup        # starts Docker DB, fetches deps, creates DBs, builds assets
mix phx.server   # start the dev server at http://localhost:4000
```

Dev emails (magic links) are captured in memory — visit `http://localhost:4000/dev/mailbox`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full development guide.

## License

MIT — see [LICENSE](LICENSE).
