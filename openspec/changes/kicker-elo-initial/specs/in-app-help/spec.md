## ADDED Requirements

### Requirement: Each tenant has a help page explaining the system
The application SHALL provide a help page at `/:tenant_slug/help` accessible to all authenticated players. The content SHALL be dynamically adapted to the active tenant's configuration so that the help text matches the actual rules in force for that tenant.

The help page SHALL explain:
- **Game formats**: which formats are enabled (1v1, 2v2, 2v1) and how teams are assigned
- **Round rules**: the configured `rounds_to_win` and `points_per_round` values, shown as concrete numbers
- **Confirmation mode**: whether the tenant uses trust-based or confirmation-based mode; if confirmation-based, the auto-confirm timeout and how to confirm or dispute a game
- **Elo rating system**: what the rating represents, how it is calculated (team average, expected score, delta), and what the starting rating is (1000)
- **K-factor decay**: the three rating bands and their K-factors, explained in plain language
- **Team balancer**: how the widget works and how it selects the fairest split

#### Scenario: Help page reflects trust-based tenant
- **WHEN** an authenticated player visits `/:tenant_slug/help` and the tenant uses trust-based mode
- **THEN** the confirmation section explains that games take effect immediately, without mentioning confirmation or dispute flows

#### Scenario: Help page reflects confirmation-based tenant
- **WHEN** an authenticated player visits `/:tenant_slug/help` and the tenant uses confirmation-based mode
- **THEN** the confirmation section explains the confirm/dispute flow and shows the auto-confirm timeout in hours

#### Scenario: Help page shows actual configured round rules
- **WHEN** an authenticated player visits the help page
- **THEN** the round rules section shows the tenant's actual `rounds_to_win` and `points_per_round` values, not generic defaults

### Requirement: Contextual tooltips explain key concepts inline
The application SHALL provide a tooltip component that can be attached to any UI element. Tooltips SHALL be keyboard-accessible (triggered by focus as well as hover) and dismissable via Escape. They SHALL be used on the following elements:

- **Elo rating display** (leaderboard, player profile, dashboard): explains what the number means
- **K-factor indicator** (player profile): explains the current K-factor band and when it changes
- **Team balancer expected score**: explains what the percentage means
- **Confirmation mode indicators** (pending game badges): explains what "pending" means and what action is available
- **Auto-confirm countdown**: explains that the game will auto-confirm after the shown time

#### Scenario: Keyboard user accesses tooltip
- **WHEN** a keyboard user focuses an element that has a tooltip
- **THEN** the tooltip content is shown (or announced via aria-describedby) and pressing Escape dismisses it

#### Scenario: Screen reader user receives tooltip content
- **WHEN** a screen reader user focuses a tooltipped element
- **THEN** the tooltip content is announced via `aria-describedby` without requiring hover
