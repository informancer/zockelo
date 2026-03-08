## ADDED Requirements

### Requirement: Application meets WCAG 2.1 AA accessibility standard
The application SHALL conform to WCAG 2.1 Level AA. This applies to all pages including the SVG foosball table, player card picker, leaderboard, and admin panels.

#### Scenario: Automated accessibility scan passes
- **WHEN** an automated a11y scan (e.g. axe-core) is run against any page
- **THEN** no WCAG 2.1 AA violations are reported

### Requirement: SVG foosball table is keyboard-navigable and screen-reader-friendly
The foosball table position slots SHALL be focusable via keyboard (Tab key) and activatable via Enter/Space. Each slot SHALL have an ARIA label describing its role (e.g. "Team 1 Front — unassigned" or "Team 1 Front — Alice"). The player card picker overlay SHALL trap focus while open and restore focus to the triggering slot on close.

#### Scenario: Keyboard user assigns a player
- **WHEN** a keyboard user tabs to a position slot and presses Enter
- **THEN** the player card picker overlay opens with focus on the filter input

#### Scenario: Overlay closes and returns focus
- **WHEN** a keyboard user selects a player or presses Escape in the picker overlay
- **THEN** the overlay closes and focus returns to the slot that triggered it

#### Scenario: Assigned slot announces player name to screen readers
- **WHEN** a screen reader user focuses a filled position slot
- **THEN** the ARIA label announces the player name and position (e.g. "Team 1 Front — Alice, rating 1842")

### Requirement: Live leaderboard updates are announced to screen readers
The leaderboard SHALL use `aria-live="polite"` so that rating changes after a game confirmation are announced to screen reader users without interrupting their current focus.

#### Scenario: Screen reader announces leaderboard update
- **WHEN** ratings update and the leaderboard re-renders
- **THEN** the changed rows are announced by the screen reader via the aria-live region

### Requirement: Colour contrast meets WCAG AA requirements
All text and interactive elements SHALL meet a minimum contrast ratio of 4.5:1 against their background. The red and black team colours used in the SVG foosball table SHALL be distinguishable both by colour and by label (not colour alone).

#### Scenario: Team colours are not the only differentiator
- **WHEN** a user with colour blindness views the foosball table
- **THEN** team identity is communicated via labels ("Team 1", "Team 2") in addition to colour

### Requirement: Focus styles are visible for keyboard users
All interactive elements SHALL have a clearly visible `:focus-visible` style. The default browser outline SHALL NOT be removed with `outline: none` unless replaced with an equally visible custom focus indicator. This satisfies WCAG 2.4.7 (Focus Visible, Level AA).

#### Scenario: Keyboard user sees focus on interactive elements
- **WHEN** a keyboard user tabs through interactive elements
- **THEN** each focused element has a clearly visible focus indicator (ring, outline, or equivalent) with sufficient contrast against its background

### Requirement: Motion and animation respect user preferences
Any CSS transitions or animations SHALL be disabled or reduced when the user has enabled the `prefers-reduced-motion: reduce` OS/browser preference. Components using transitions (theme toggle, overlay open/close, banner slide-in) SHALL wrap their animation properties in a `@media (prefers-reduced-motion: no-preference)` block.

#### Scenario: Animations disabled for reduced-motion preference
- **WHEN** a user has `prefers-reduced-motion: reduce` set
- **THEN** no transitions or animations play; state changes are instant

### Requirement: Touch targets meet minimum size requirements
All interactive elements (buttons, slots, player cards, nav items) SHALL have a minimum touch target size of 44×44px on mobile, per WCAG 2.5.5.

#### Scenario: Position slots are large enough to tap accurately
- **WHEN** the foosball table is rendered on a 375px-wide screen (iPhone SE)
- **THEN** each position slot has a touch target of at least 44×44px
