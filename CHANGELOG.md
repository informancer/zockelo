# Changelog

All notable changes to Zockelo will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - TBD

### Added

- Multi-tenant foosball Elo rating tracker
- 1v1, 2v2, and 2v1 game logging with per-round scores
- Elo rating system with K-factor decay (K=40/32/20 by rating band)
- Game confirmation flow: trust mode and confirmation-based mode with auto-confirm timeout
- Dispute and reinstate/void workflow for contested games
- Magic-link authentication (no passwords)
- Per-player encryption keys with crypto-shredding for GDPR-compliant deletion
- GDPR audit log for key deletion events
- Tenant admin panel: player management, invite links, config, GDPR tools
- Super admin panel: tenant management, system config
- Installable PWA with offline support (Android)
- Inter font vendored locally (no external font requests)
- Self-hosted deployment via Docker Compose + Caddy

[Unreleased]: https://github.com/informancer/zockelo/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/informancer/zockelo/releases/tag/v1.0.0
