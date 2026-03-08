## ADDED Requirements

### Requirement: Application provides consistent error pages
The application SHALL render custom error pages for common HTTP error conditions. Error pages SHALL use the standard application layout (including footer with legal links) but SHALL NOT require authentication. No internal stack traces or technical details SHALL be shown to users in production.

### Requirement: 404 Not Found page
The system SHALL render a friendly 404 page for unknown routes, missing resources, and tenant isolation denials (which return 404 rather than 403 to avoid revealing tenant existence).

#### Scenario: Unknown route returns 404
- **WHEN** a user navigates to a URL that does not match any route
- **THEN** a 404 page is displayed with a link back to the home page

#### Scenario: Tenant isolation denial returns 404
- **WHEN** an authenticated player from tenant A accesses a tenant B URL
- **THEN** a 404 page is displayed (not a 403, to avoid revealing tenant existence)

### Requirement: 500 Internal Server Error page
The system SHALL render a friendly 500 page for unhandled exceptions. The page SHALL show a generic message without stack traces or internal details. The error SHALL be captured by GlitchTip (when configured).

#### Scenario: Unhandled exception shows generic error page
- **WHEN** an unhandled exception occurs during a request
- **THEN** the user sees a friendly 500 error page; no stack trace is visible; the error is reported to GlitchTip

### Requirement: Connectivity loss shows an inline error in LiveView
When a LiveView loses its WebSocket connection, the application SHALL display an inline reconnecting indicator rather than a blank page. If reconnection fails after a timeout, a user-friendly message SHALL prompt the player to reload.

#### Scenario: LiveView reconnects automatically
- **WHEN** a player's LiveView connection drops briefly
- **THEN** Phoenix LiveView automatically reconnects and the page resumes without data loss

#### Scenario: Persistent disconnection prompts reload
- **WHEN** a LiveView connection cannot be re-established after the reconnect timeout
- **THEN** a message is displayed prompting the player to reload the page
