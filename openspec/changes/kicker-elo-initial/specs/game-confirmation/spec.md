## ADDED Requirements

### Requirement: Tenants can be configured in trust-based or confirmation mode
Each tenant SHALL have a `confirmation_mode` setting. In `trust` mode, ratings update immediately after `GameLogged`. In `confirmation` mode, ratings update only after `GameConfirmed`.

#### Scenario: Trust-mode game updates ratings immediately
- **WHEN** a game is logged in a trust-mode tenant
- **THEN** the ratings projection updates all four players' ratings immediately

#### Scenario: Confirmation-mode game stays pending until confirmed
- **WHEN** a game is logged in a confirmation-mode tenant
- **THEN** the game status is `pending` and ratings are not updated until confirmation

### Requirement: Participants and tenant admins can confirm a pending game
In confirmation mode, any participant in the game (a player on either team) or any tenant admin SHALL be able to confirm a pending game.

#### Scenario: Participant confirms a game
- **WHEN** a participant in a pending game clicks confirm
- **THEN** a `GameConfirmed` event is emitted and the ratings projection updates

#### Scenario: Tenant admin confirms a game
- **WHEN** a tenant admin confirms a pending game
- **THEN** a `GameConfirmed` event is emitted and the ratings projection updates

### Requirement: Pending games auto-confirm after a configurable timeout
In confirmation mode, a pending game SHALL automatically be confirmed after `auto_confirm_after_hours` hours (per-tenant config) if no dispute has been raised.

#### Scenario: Game auto-confirms after timeout
- **WHEN** a pending game has been unconfirmed for longer than `auto_confirm_after_hours`
- **THEN** a `GameConfirmed` event is emitted by the system and ratings are updated

### Requirement: Participants and tenant admins can dispute a game
In confirmation mode, any participant or tenant admin SHALL be able to dispute a pending game. A disputed game SHALL NOT have its ratings updated.

#### Scenario: Participant disputes a game
- **WHEN** a participant disputes a pending game
- **THEN** a `GameDisputed` event is emitted and the game status becomes `disputed`; auto-confirm is cancelled

#### Scenario: Tenant admin disputes a game
- **WHEN** a tenant admin disputes a game (pending or confirmed)
- **THEN** a `GameDisputed` event is emitted

### Requirement: Tenant admins can reinstate or void a disputed game
A tenant admin SHALL be able to either reinstate a disputed game (ratings apply) or void it (game is discarded, no rating changes).

#### Scenario: Tenant admin reinstates a disputed game
- **WHEN** a tenant admin reinstates a disputed game
- **THEN** a `GameReinstated` event is emitted and ratings are updated as if the game were confirmed

#### Scenario: Tenant admin voids a disputed game
- **WHEN** a tenant admin voids a disputed game
- **THEN** a `GameVoided` event is emitted and no rating changes are applied; the game remains in history marked as voided

### Requirement: Pending games behave predictably when a participant is deleted
If a participant in a pending or disputed game is deleted before the game is confirmed, the game SHALL be automatically voided. A `GameVoided` event SHALL be emitted at the time of player deletion (as part of the deletion flow), and the game SHALL be removed from all pending queues. Ratings are not updated.

#### Scenario: Participant deleted before confirmation voids the game
- **WHEN** a player who is a participant in a pending game is deleted
- **THEN** a `GameVoided` event is emitted for that game during the deletion flow; the game status becomes `voided`; no rating changes are applied

### Requirement: Tenant config changes do not retroactively affect pending games
`rounds_to_win` and `points_per_round` config changes take effect for games logged **after** the change. Pending games that were logged before the config change SHALL be confirmed or voided using the config values that were active when the game was logged. The `GameLogged` event SHALL record the `rounds_to_win` and `points_per_round` values at the time of logging.

#### Scenario: Config change does not affect pending games
- **WHEN** a tenant admin changes `rounds_to_win` from 2 to 3 while a game is pending confirmation
- **THEN** the pending game retains its original winning condition (rounds_to_win=2) for confirmation purposes; newly logged games use rounds_to_win=3
