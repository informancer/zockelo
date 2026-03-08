# Contributing to Zockelo

## Development Environment Setup

Requirements: Elixir 1.18 / OTP 27 (managed via [mise](https://mise.jdx.dev) or asdf, see `.tool-versions`), Docker.

```sh
mix setup        # starts Docker DB, fetches deps, creates DBs, builds assets
mix phx.server   # start the dev server at http://localhost:4000
```

Dev emails (magic links) are captured in memory — visit `http://localhost:4000/dev/mailbox` to view and click magic links without SMTP setup.

## Running Tests

```sh
mix test
```

The `test` alias creates and migrates both the Ecto and EventStore test databases automatically.

## Code Quality

Before opening a PR, run:

```sh
mix precommit    # compile --warnings-as-errors, format check, tests
mix sobelow      # security scan
mix deps.audit   # dependency CVE audit
```

Fix all warnings and failures before requesting review.

## Coding Conventions

- **Credo** — follow the default ruleset; run `mix credo` to check.
- **Dialyzer** — type-check with `mix dialyzer` (first run is slow; results are cached).
- **Sobelow** — security linting via `mix sobelow`.
- **Formatting** — `mix format` is enforced by CI.

## Commit Message Style

Use imperative mood in the subject line, 72-character limit:

```
Add player deletion with crypto-shredding

Dispatches DeletePlayer command which removes the encryption key,
inserts a GDPR audit record, and voids pending games for the player.
```

Reference issues with `Fixes #123` or `Closes #123` in the body.

## Pull Request Process

1. Fork the repo and create a branch from `develop`.
2. Write tests for new behaviour.
3. Run `mix precommit` and fix all failures.
4. Complete the **Privacy Review Checklist** below if applicable.
5. Open a PR against `develop` with a clear description of the change.

## Privacy Review Checklist

Complete this checklist for any PR that adds or modifies data processing:

- [ ] **No new PII in logs** — grep new `Logger` calls and confirm they don't include names, emails, or IDs that map to a natural person.
- [ ] **No external references in email templates** — confirm email templates contain no external URLs, tracking pixels, or remote fonts.
- [ ] **Privacy notice updated** — if new personal data is collected or a new processing purpose introduced, update `priv/privacy_notice.md` and note the change in the PR description.
- [ ] **Cookie/token documented** — if a new cookie or session token is added, confirm it is strictly necessary (functional, not tracking), document its TTL in the PR description, and add it to the cookie inventory in `priv/privacy_notice.md`.
