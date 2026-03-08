## ADDED Requirements

### Requirement: Root URL shows context-aware landing page
The root URL (`/`) of the application SHALL render a page appropriate to the current system state:

| System state | Visitor | Behaviour |
|---|---|---|
| No super admin exists yet | Any | "Getting started" setup instructions page — links to docs, shows the `./bin/zockelo eval` command to create a super admin |
| Super admin exists, no tenants yet | Authenticated super admin | Redirect to `/admin` |
| Super admin exists, no tenants yet | Anyone else | "No workspaces available yet" page |
| At least one tenant exists | Authenticated player | Redirect to `/:tenant_slug/` for their tenant |
| At least one tenant exists | Authenticated super admin | Redirect to `/admin` |
| At least one tenant exists | Unauthenticated visitor | Neutral branded "Enter your workspace URL" page with a text field for the tenant slug and a "Go" button |

**The neutral page is shown for any number of tenants** (single or multiple) — the system does not auto-redirect based on tenant count. This keeps the behaviour predictable for operators and avoids leaking the number of tenants to unauthenticated visitors.

The neutral page SHALL include:
- The app name (`app_name` system config, defaulting to "Zockelo")
- A brief description: "Enter your workspace name to get started"
- A slug input field with a "Go" button that navigates to `/:slug/login`
- Footer links: imprint and privacy are tenant-scoped and not available at root level; the footer MAY show a generic link to system documentation

#### Scenario: Fresh install — setup instructions shown
- **WHEN** no super admin exists and any visitor accesses `/`
- **THEN** the "Getting started" page is displayed with the super admin creation command

#### Scenario: Super admin exists, no tenants — super admin redirected to /admin
- **WHEN** a super admin accesses `/` and no tenants exist yet
- **THEN** they are redirected to `/admin`

#### Scenario: Tenants exist — unauthenticated visitor sees neutral page
- **WHEN** one or more tenants exist and an unauthenticated visitor accesses `/`
- **THEN** the neutral "Enter your workspace URL" page is shown regardless of how many tenants exist

#### Scenario: Tenants exist — authenticated player redirected to their tenant
- **WHEN** one or more tenants exist and an authenticated player accesses `/`
- **THEN** they are redirected to `/:tenant_slug/`

#### Scenario: Workspace slug submitted from neutral page
- **WHEN** a visitor enters a slug in the neutral page input and submits
- **THEN** they are navigated to `/:slug/login`

### Requirement: Dashboard is the landing page for authenticated players
The dashboard SHALL be the default page after login at `/:tenant_slug/`. It SHALL display:
- Mini leaderboard (top 5 players by rating)
- The current player's stats: rank, current rating, games played, win rate, recent form (last 5 results)
- Recent games (last 5 games in the tenant)
- Pending games awaiting the current player's confirmation (in confirmation mode)
- Tenant stats: total active players, total games played
- Team balancer widget (see below)

#### Scenario: Player lands on dashboard after login
- **WHEN** a player successfully authenticates via magic link
- **THEN** they are redirected to `/:tenant_slug/`

#### Scenario: Dashboard shows pending games to confirm
- **WHEN** the tenant is in confirmation mode and the current player has games awaiting confirmation
- **THEN** the pending games are shown prominently on the dashboard with confirm/dispute actions

#### Scenario: Empty state for new tenant
- **WHEN** a player visits the dashboard and no games have been logged yet
- **THEN** an empty state is shown with a prompt to log the first game

#### Scenario: Empty state for new player
- **WHEN** a player visits the dashboard and has not played any games yet
- **THEN** their stats section shows an empty state with a prompt to log their first game

### Requirement: Dashboard includes a team balancer widget
The dashboard SHALL include a team balancer widget that suggests the fairest team split for a selected group of 2–4 players based on their current Elo ratings. The widget SHALL:

1. Display all active players as toggleable chips/cards — tap to include in the group
2. Calculate and display the fairest split once 2–4 players are selected
3. Show the suggested team arrangement with team average ratings and expected score
4. Provide a "Log this game" button that pre-fills the game logging form with the suggested arrangement

**Balancing algorithm:**
- **2 players**: single option (1v1), trivially fair
- **3 players**: evaluate all 3 pairings (each player as the solo in 2v1); recommend the split minimising `|solo_rating - team_avg|`
- **4 players**: evaluate all 3 pairings (2v2); recommend the split minimising `|team1_avg - team2_avg|`

The widget SHALL show a prompt if fewer than 2 or more than 4 players are selected.

#### Scenario: Four players selected — fairest 2v2 suggested
- **WHEN** a player selects 4 players in the team balancer widget
- **THEN** the system evaluates all 3 pairings, displays the fairest split with team averages and expected score percentage

#### Scenario: Three players selected — fairest 2v1 suggested
- **WHEN** a player selects 3 players in the team balancer widget
- **THEN** the system evaluates all 3 solo configurations and displays the fairest 2v1 split

#### Scenario: Two players selected — 1v1 shown
- **WHEN** a player selects 2 players in the team balancer widget
- **THEN** the system displays the 1v1 matchup with both players' ratings

#### Scenario: Log this game pre-fills the logging form
- **WHEN** a player taps "Log this game" in the team balancer widget
- **THEN** the game logging form opens with the suggested team arrangement pre-filled; player still assigns front/back positions on the foosball table

#### Scenario: Invalid selection count
- **WHEN** fewer than 2 or more than 4 players are selected
- **THEN** the widget shows a prompt: "Select 2–4 players to see the fairest split"

### Requirement: Application has consistent navigation
The application SHALL provide navigation appropriate to screen size:
- **Mobile (PWA)**: fixed bottom navigation bar with: Dashboard, Log Game (primary action), Games, Profile
- **Desktop**: top navigation bar with the same items

The navigation SHALL be visible on all authenticated pages. Admin panel access SHALL be available via the user menu (avatar/initials) for users with tenant admin or super admin roles.

#### Scenario: Mobile navigation renders as bottom bar
- **WHEN** an authenticated player views any page on a mobile-sized screen
- **THEN** a fixed bottom navigation bar is displayed with Dashboard, Log Game, Games, and Profile items

#### Scenario: Desktop navigation renders as top bar
- **WHEN** an authenticated player views any page on a desktop-sized screen
- **THEN** a top navigation bar is displayed with the same navigation items

#### Scenario: Admin panel link visible to admins
- **WHEN** a tenant admin or super admin opens the user menu
- **THEN** a link to the relevant admin panel is shown

### Requirement: Magic link request shows confirmation page
After a player submits their email on the login page, the system SHALL show a confirmation page instructing them to check their email. The confirmation page SHALL NOT reveal whether the email address is registered.

#### Scenario: Login form submission shows check-your-email page
- **WHEN** a player submits an email address on the login page
- **THEN** the system displays a "Check your email" confirmation page regardless of whether the email is registered

### Requirement: The PWA requires an active connection (online-only for v1)
The application SHALL require an active internet connection for all functionality. No offline caching of application data SHALL be implemented in v1. The service worker SHALL only be used for PWA installability (manifest, install prompt) — not for offline data serving. A user-friendly error SHALL be shown when connectivity is lost.

#### Scenario: User goes offline
- **WHEN** a player loses internet connectivity while using the app
- **THEN** a connectivity error is displayed and no stale data is served

### Requirement: Leaderboard displays current rankings for a tenant
The leaderboard page SHALL display all active players in a tenant sorted by current Elo rating descending. It SHALL show: rank, player name, current rating, games played, wins, losses, win rate.

**Sort order (to resolve ties):** rating descending → games played descending (more experienced player ranked higher) → player name ascending (alphabetical as final tiebreaker).

#### Scenario: Leaderboard renders all active players
- **WHEN** an authenticated player visits `/:tenant_slug/leaderboard`
- **THEN** all active players are listed sorted by rating descending with rank numbers

#### Scenario: Deleted players do not appear on the leaderboard
- **WHEN** a player has been deleted
- **THEN** they do not appear in the leaderboard list

### Requirement: Leaderboard updates in real time via LiveView
The leaderboard SHALL update automatically when a game is confirmed and ratings change, without requiring a page refresh.

#### Scenario: Leaderboard updates after game confirmation
- **WHEN** a game is confirmed and ratings are updated in the projection
- **THEN** all connected clients viewing the leaderboard see the updated rankings within seconds

### Requirement: Game history is paginated, browsable, and filterable
The game history page SHALL display past games for a tenant, sorted by date descending, paginated. Each game entry SHALL show: date, team1 players with positions, team2 players with positions, per-round scores, match result, game status (pending/confirmed/disputed/voided).

The page SHALL support filtering by:
- **Player**: show only games involving a selected player
- **Date range**: show only games within a selected from/to date range

Filters SHALL be combinable. Active filters SHALL be reflected in the URL query string so filtered views are shareable/bookmarkable.

#### Scenario: Game history loads for a tenant
- **WHEN** an authenticated player visits `/:tenant_slug/games`
- **THEN** a paginated list of past games is displayed with team, position, and score details

#### Scenario: Game history filtered by player
- **WHEN** a player selects a player filter on the game history page
- **THEN** only games involving that player are shown and the filter is reflected in the URL

#### Scenario: Game history filtered by date range
- **WHEN** a player sets a from/to date range filter
- **THEN** only games within that range are shown and the filter is reflected in the URL

#### Scenario: Filters are combinable
- **WHEN** a player applies both a player filter and a date range filter
- **THEN** only games matching both criteria are shown

#### Scenario: Deleted player shown as anonymised in game history
- **WHEN** a game history entry involves a deleted player
- **THEN** that player is shown as `[Deleted Player]`

### Requirement: Player profile shows individual stats, a rating chart, and game history
The player profile page SHALL display: current rating, games played, wins, losses, win rate, a visual rating history chart, and a chronological list of past games with the rating delta for each.

The rating chart SHALL be rendered using Chart.js via a LiveView JS hook. It SHALL show rating over time as a line chart with one data point per game. Tapping/hovering a data point SHALL show a tooltip with the date, opponent names, and rating change. The chart SHALL be responsive and scale to the container width.

#### Scenario: Player profile renders rating history
- **WHEN** an authenticated player visits `/:tenant_slug/players/:player_id`
- **THEN** the page shows the player's current rating and a list of past games with before/after rating for each

#### Scenario: Player cannot view profile of a deleted player
- **WHEN** a player navigates to the profile of a deleted player
- **THEN** the system renders a `[Deleted Player]` placeholder page with no PII
