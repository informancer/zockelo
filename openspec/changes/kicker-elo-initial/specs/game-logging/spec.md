## ADDED Requirements

### Requirement: Players can log a game with round-level scores and per-round positions
Any activated player in a tenant SHALL be able to log a game. A game consists of two teams (each 1–2 players) and one or more rounds. Each round records: the score for both teams AND the front/back position of each player on their team. Positions MAY change between rounds (players swap front/back freely).

For 1v1 games, no position is recorded (single player per team, position is meaningless). For 2v1 games, the team of two records front/back; the solo player has no position label.

#### Scenario: Player logs a valid 2v2 game with positions
- **WHEN** a player submits a game with two teams of two, each round specifying front/back assignments and scores
- **THEN** a `GameLogged` event is emitted with full team composition, per-round positions, and per-round scores

#### Scenario: Positions differ between rounds
- **WHEN** team players swap front/back between rounds
- **THEN** each round independently records the positions for that round

#### Scenario: Player logs a valid 1v1 game
- **WHEN** a player submits a game with one player per team and valid round scores
- **THEN** a `GameLogged` event is emitted with no position data

#### Scenario: Player logs a valid 2v1 game
- **WHEN** a player submits a game with two players on one team and one player on the other
- **THEN** a `GameLogged` event is emitted; the team of two records front/back per round, the solo player has no position label

### Requirement: Score validation enforces tenant configuration
The system SHALL reject round scores that are inconsistent with the tenant's `points_per_round` setting. The UI SHALL block invalid scores before submission. The backend SHALL also validate and reject invalid scores.

#### Scenario: Valid winning score accepted
- **WHEN** a round score has exactly `points_per_round` points for the winner (e.g. 7–4 with points_per_round=7)
- **THEN** the score is accepted

#### Scenario: Score exceeding points_per_round rejected
- **WHEN** a round score has more than `points_per_round` points for either team (e.g. 8–6 with points_per_round=7)
- **THEN** the backend rejects the game with a validation error

#### Scenario: UI blocks invalid score input
- **WHEN** a player enters a score that would exceed `points_per_round` in the game logging form
- **THEN** the UI prevents submission and shows an inline validation error

### Requirement: Each player may appear in a game at most once
No player_id SHALL appear more than once across all team slots in a single game — whether on the same team or on opposing teams. This is enforced at both the UI and backend levels:

- **UI**: Once a player is assigned to any slot, they appear greyed out and non-selectable in the player card picker for all remaining slots. Tapping a filled slot to reassign it unblocks the currently assigned player first, then shows the picker with that player available again.
- **Backend**: The `GameLogged` command handler SHALL reject any submission where a player_id appears more than once across team1 and team2, regardless of how it was submitted.

#### Scenario: Player already assigned to a slot is unavailable in picker
- **WHEN** a player has been assigned to any slot in the current game and another slot's picker is opened
- **THEN** the assigned player is shown greyed out and cannot be selected for the second slot — regardless of whether the second slot is on the same team or the opposing team

#### Scenario: Reassigning a slot makes the previous player selectable again
- **WHEN** a player taps a slot that already has a player assigned in order to change it
- **THEN** the picker opens with the currently assigned player available again (unblocked), and selecting a new player replaces the previous assignment

#### Scenario: Duplicate player_id across teams rejected at backend
- **WHEN** a game is submitted with the same player_id appearing in both team1 and team2
- **THEN** the backend rejects the game with a validation error

#### Scenario: Duplicate player_id within a team rejected at backend
- **WHEN** a game is submitted with the same player_id appearing twice in team1 or team2
- **THEN** the backend rejects the game with a validation error

### Requirement: Winning condition is validated before submission
The game logging form SHALL prevent submission until one team has won `rounds_to_win` rounds. The backend SHALL also validate this condition and reject games that have no winner or have an impossible round count.

#### Scenario: Form blocked until winner is determined
- **WHEN** a player has entered rounds but neither team has reached `rounds_to_win` wins
- **THEN** the submit button is disabled and an inline message shows "Keep entering rounds until a team wins"

#### Scenario: Game with invalid round count rejected at backend
- **WHEN** a submitted game has no team reaching `rounds_to_win` wins
- **THEN** the backend rejects it with a validation error

### Requirement: Game submission provides contextual feedback
After a game is successfully submitted, the player SHALL receive feedback appropriate to the tenant's confirmation mode:
- **Trust mode:** a success message "Game logged — ratings updated" and a redirect to the dashboard where updated ratings are visible
- **Confirmation mode:** a success message "Game logged — waiting for confirmation from [other player name(s)]" and a redirect to the dashboard where the pending game is visible in the "Pending games" section

#### Scenario: Trust mode — success with rating update message
- **WHEN** a game is logged in a trust-mode tenant
- **THEN** a success message "Game logged — ratings updated" is shown and the player is redirected to the dashboard

#### Scenario: Confirmation mode — pending message shown
- **WHEN** a game is logged in a confirmation-mode tenant
- **THEN** a message "Game logged — waiting for confirmation" is shown naming the other participant(s), and the player is redirected to the dashboard where the pending game card is visible

### Requirement: Game logging UI presents a visual foosball table
The game logging form SHALL render a top-down SVG foosball table with red and black player figures. Tappable position slots SHALL flank the table — one pair (front/back) per team side. Tapping a slot opens a player card picker overlay. For 1v1 games, a single slot per side is shown with no front/back distinction.

The player card picker SHALL display all **active** (non-deleted) players in the tenant as tappable cards showing name and current rating. A search/filter input at the top of the overlay allows filtering by name. Players already assigned to any slot in the current game SHALL be shown as unavailable (greyed out).

**When the tenant has two or fewer active players,** the form SHALL pre-fill both team slots automatically without requiring the player card picker. The picker is still accessible via tap if the player wants to change an assignment.

For rounds after the first, all position slots SHALL be pre-filled with the assignments from the previous round. Players can tap a slot to re-assign it (e.g. to swap front↔back within their team).

#### Scenario: Logging form shows foosball table with position slots
- **WHEN** a player opens the game logging form
- **THEN** a top-down foosball table SVG is displayed with four tappable slots (T1 Back, T1 Front, T2 Front, T2 Back) flanking the table

#### Scenario: Player card picker opens on slot tap (empty slot)
- **WHEN** a player taps an unassigned position slot
- **THEN** a player card overlay appears with all active players, a filter input, and already-assigned players greyed out

#### Scenario: Player card picker opens on slot tap (filled slot — correction)
- **WHEN** a player taps a slot that already has a player assigned
- **THEN** the picker overlay opens with the current slot's player unblocked and available for selection; all other already-assigned players remain greyed out; selecting a different player replaces the previous assignment

#### Scenario: Round 2+ positions pre-filled from previous round
- **WHEN** a player advances to entering round 2 or later
- **THEN** all position slots are pre-filled with the previous round's assignments; the player can tap any slot to change it

#### Scenario: 1v1 game shows single slot per side
- **WHEN** the game logging form is used for a 1v1 game
- **THEN** one slot per team side is shown with no front/back label

### Requirement: GameLogged event contains full game data including per-round positions
The `GameLogged` event SHALL contain: game_id, tenant_id, logged_by (player_id), logged_at (UTC), team1_players (list of player_ids), team2_players (list of player_ids), rounds (list of {team1_front, team1_back, team2_front, team2_back, team1_score, team2_score}). Position fields SHALL be nil for 1v1 games and for the solo player in 2v1 games.

#### Scenario: GameLogged event is complete with positions
- **WHEN** a valid 2v2 game is submitted
- **THEN** the emitted `GameLogged` event contains team membership, and each round entry includes front/back player_ids and scores with no PII (only player UUIDs)
