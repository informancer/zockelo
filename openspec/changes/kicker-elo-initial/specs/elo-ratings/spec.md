## ADDED Requirements

### Requirement: Individual ratings are maintained via a projection
The system SHALL maintain a `player_ratings` read model, updated by a projection that processes `GameConfirmed` (or `GameLogged` in trust mode) events. Each record SHALL contain: player_id, tenant_id, current_rating, games_played, wins, losses, updated_at. Initial rating for a new player SHALL be 1000.

#### Scenario: New player has initial rating of 1000
- **WHEN** a `PlayerActivated` event is processed by the ratings projection
- **THEN** the player is added to `player_ratings` with a rating of 1000 and games_played of 0

#### Scenario: Ratings update after a confirmed game
- **WHEN** a `GameConfirmed` event (or `GameLogged` in trust mode) is processed
- **THEN** all players in the game have their ratings, games_played, wins, and losses updated

### Requirement: Team expected score uses average team rating
The expected score for a team SHALL be calculated as:
```
team_rating = average(player ratings on team)
expected    = 1 / (1 + 10^((opponent_team_rating - team_rating) / 400))
```
This formula applies regardless of team size (1v1, 2v2, 2v1).

#### Scenario: Expected score calculated from team averages
- **WHEN** a game involves team1 with avg rating 1400 and team2 with avg rating 1600
- **THEN** team1's expected score is approximately 0.24 and team2's is approximately 0.76

### Requirement: K-factor decays based on individual player rating
Each player's K-factor SHALL be determined by their rating at the time of the game:
- Rating < 1400 → K = 40
- 1400 ≤ Rating < 1800 → K = 32
- Rating ≥ 1800 → K = 20

#### Scenario: New player has K=40
- **WHEN** a player with rating 950 plays a game
- **THEN** their K-factor used for the rating update is 40

#### Scenario: Established player has K=20
- **WHEN** a player with rating 1850 plays a game
- **THEN** their K-factor used for the rating update is 20

### Requirement: Rating delta is calculated per player using their own K-factor
After a game, each player's rating SHALL be updated individually using their own K-factor:
```
delta = K_player × (actual - expected)
  actual: 1 for win, 0 for loss
new_rating = current_rating + delta
```

#### Scenario: Winning player's rating increases
- **WHEN** a player wins a game
- **THEN** their rating increases by `K × (1 - expected_score_for_their_team)`

#### Scenario: Losing player's rating decreases
- **WHEN** a player loses a game
- **THEN** their rating decreases by `K × (0 - expected_score_for_their_team)`

### Requirement: Player ratings have a minimum floor
A player's rating SHALL never fall below 100. After computing a rating delta, if the resulting rating would be below 100, it SHALL be clamped to 100. This prevents ratings from reaching zero or going negative through sustained losses, which would produce mathematically nonsensical expected scores.

#### Scenario: Rating clamped at floor after heavy losses
- **WHEN** a player's current rating is 120 and a game result would reduce it by 40
- **THEN** the new rating is set to 100 rather than 80

#### Scenario: Rating above floor is not affected
- **WHEN** a player's current rating is 800 and a game result would reduce it by 30
- **THEN** the new rating is 770 (no clamping applied)

### Requirement: Ratings projection can be fully rebuilt from events
The ratings projection SHALL be derivable by replaying all `GameLogged` / `GameConfirmed` / `GameVoided` events from the beginning. Rebuilding the projection SHALL produce identical results to the current state.

#### Scenario: Projection rebuild produces consistent ratings
- **WHEN** the `player_ratings` table is dropped and the projection is rebuilt from the event stream
- **THEN** all player ratings match the previously stored values (for players whose keys are intact)
