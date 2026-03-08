## ADDED Requirements

### Requirement: Each tenant has a configurable imprint (§5 TMG)
Each tenant SHALL have an imprint page publicly accessible at `/:tenant_slug/imprint` without requiring authentication. The imprint SHALL be configured by a tenant admin and consist of the following structured fields:

**Mandatory fields:**
- Provider name (Anbieter) — company name and legal form, or full name for individuals
- Address (Anschrift) — four discrete sub-fields: street and number, postal code, city, **country (ISO 3166-1 alpha-2 code, stored separately from the rest of the address so it can be used for supervisory authority lookup)**
- Email address (for direct contact)
- Legal representative (Vertretungsberechtigte Person) — e.g. "Geschäftsführer: Max Mustermann"

Country is mandatory because it determines the competent supervisory authority shown in the privacy notice. The admin panel SHALL warn if country is missing, separately from the general "incomplete imprint" warning.

**Optional fields:**
- Phone number (empfohlen)
- Commercial register entry (Handelsregistereintrag) — register court and number
- VAT identification number (Umsatzsteuer-Identifikationsnummer)
- Regulatory authority (Aufsichtsbehörde) — for licensed/regulated businesses
- Additional free text — for edge cases not covered by structured fields

The imprint SHALL be rendered as a formatted page using the structured fields. Tenants with an incomplete imprint (missing mandatory fields) SHALL be shown a warning in the tenant admin panel.

#### Scenario: Public access without login
- **WHEN** any user (authenticated or not) visits `/:tenant_slug/imprint`
- **THEN** the imprint page is rendered without requiring authentication

#### Scenario: Tenant admin configures imprint
- **WHEN** a tenant admin fills in the imprint fields and saves
- **THEN** the imprint page immediately reflects the updated information

#### Scenario: Incomplete imprint shows admin warning
- **WHEN** a tenant admin views the admin panel and mandatory imprint fields are missing
- **THEN** a warning is displayed prompting them to complete the imprint

### Requirement: Each tenant has a privacy notice page (GDPR Article 13)
Each tenant SHALL have a privacy notice page publicly accessible at `/:tenant_slug/privacy` without requiring authentication. The page SHALL consist of two parts:

**Part 1 — System-generated (automatically accurate):**
The system SHALL generate the factual data processing description based on what KickerElo actually processes:
- Controller identity: populated from the tenant's imprint (name, address, email)
- Data processed: name, email address, game participation data, Elo ratings, session tokens, magic link tokens
- Purpose of processing: player identification and authentication; Elo rating calculation and display; game history
- Legal basis: legitimate interest (Art. 6(1)(f) DSGVO) for game tracking; contract performance (Art. 6(1)(b)) for authentication
- Recipients: no personal data is shared with third parties; all data remains within the self-hosted deployment
- Third-country transfers: none; all data is stored on the operator's infrastructure
- Retention: game and rating data retained for the duration of the player account (maximum `retention_period_days`, shown as a concrete number of days); operational data (sessions, tokens) deleted promptly after use; admin audit log entries retained for `audit_log_retention_days` (shown as a concrete number of days) for accountability purposes even after account deletion (legal basis: legitimate interests, Art. 6(1)(f))
- Rights: the notice SHALL list each right with a brief description of how to exercise it in-app:
  - Right of access (Art. 15): "Download your data from Profile → Export my data"
  - Right to rectification (Art. 16): "Update your name or email in Profile → Settings"
  - Right to erasure (Art. 17): "Delete your account in Profile → Settings → Delete account"
  - Right to data portability (Art. 20): "Download your data from Profile → Export my data (JSON format)"
  - Right to object (Art. 21): "Contact [operator email]; or delete your account to stop all processing"
  - Right to restriction (Art. 18): "This service does not offer account suspension; account deletion (Art. 17) is the available mechanism for stopping processing"
- Cookie: session cookie name, purpose (authentication), idle timeout (8 hours), absolute maximum lifetime (7 days); classified as strictly necessary — no consent required
- Retention schedule: magic link tokens (15 minutes), sessions (8 hours idle / 7 days max), invite tokens (per-token expiry, default 30 days), player data (`retention_period_days` shown as a concrete number), audit log (`audit_log_retention_days` shown as a concrete number)
- Right to lodge a complaint: players have the right to lodge a complaint with a supervisory data protection authority (Art. 13(2)(d) GDPR). The system SHALL look up the competent authority from a **built-in static table** keyed on the imprint country code (ISO 3166-1 alpha-2). The table covers all EU/EEA member states plus GB (ICO). The lookup is best-effort:
  - **Known country, unambiguous authority** (e.g. `AT`, `FR`, `NL`): authority name and URL are rendered directly in the privacy notice
  - **`DE` (Germany)**: the federal BfDI is pre-filled with an inline note: *"Germany also has state-level (Länder) data protection authorities. If your organisation is subject to a state authority, please specify it in the privacy addendum."*
  - **Unknown or missing country**: the privacy notice renders a placeholder: *"[Supervisory authority not configured — please specify in the privacy addendum]"* and the admin panel shows a warning
  - **Country updated**: the privacy notice immediately reflects the new lookup result on the next page render — no manual action required; the imprint is the single source of truth
- Contact for data subject requests: populated from tenant imprint email; response within 30 days (Art. 12)

**Part 2 — Tenant-configurable addendum (free text):**
The tenant admin SHALL be able to add a free-text addendum for organisation-specific context (e.g. internal IT policies, DPO contact details, additional processing activities).

#### Scenario: Public access without login
- **WHEN** any user (authenticated or not) visits `/:tenant_slug/privacy`
- **THEN** the privacy notice is rendered without requiring authentication

#### Scenario: System-generated section reflects actual data processing
- **WHEN** the privacy notice page is rendered
- **THEN** the system-generated section accurately describes the data KickerElo collects and processes, using the tenant's imprint data for controller identity

#### Scenario: Retention period shown as a concrete value
- **WHEN** the privacy notice is rendered
- **THEN** the retention period is shown as the actual configured `retention_period_days` value (e.g. "730 days"), not a vague description

#### Scenario: Supervisory authority right is present in privacy notice
- **WHEN** a user views the privacy notice
- **THEN** the system-generated section includes the right to lodge a complaint with a data protection supervisory authority per Art. 13(2)(d) GDPR

#### Scenario: Competent authority pre-populated from imprint country
- **WHEN** the imprint country is set to a known EU/EEA/GB code (e.g. `AT`)
- **THEN** the privacy notice renders the corresponding authority name and URL (e.g. "Datenschutzbehörde — dsb.gv.at")

#### Scenario: Germany shows BfDI with Länder note
- **WHEN** the imprint country is `DE`
- **THEN** the privacy notice renders the BfDI with an inline note that a state authority may apply

#### Scenario: Unknown country shows placeholder and admin warning
- **WHEN** the imprint country is missing or not in the lookup table
- **THEN** the privacy notice renders a placeholder instructing the tenant admin to specify the authority; the admin panel displays a warning

#### Scenario: Updating country immediately updates the privacy notice
- **WHEN** a tenant admin changes the imprint country from one value to another and saves
- **THEN** the privacy notice immediately renders the authority corresponding to the new country on the next page load — no further action required

#### Scenario: Controller identity requires imprint to be complete
- **WHEN** the privacy notice is rendered but mandatory imprint fields are missing
- **THEN** the controller identity section shows a placeholder warning (e.g. "[Imprint incomplete — please configure in admin panel]") rather than blank fields

#### Scenario: Tenant admin adds privacy addendum
- **WHEN** a tenant admin saves a free-text addendum in the tenant admin panel
- **THEN** the addendum is appended to the privacy notice page below the system-generated section

### Requirement: Privacy notice summary shown at point of first data collection
When a player activates their account for the first time (via magic link after invitation or invite link self-registration), the activation screen SHALL display a brief privacy summary before the player gains access. The summary SHALL include:
- What data is collected (name, email, game participation)
- Link to the full privacy notice at `/:tenant_slug/privacy`
- The fact that by proceeding they acknowledge the privacy notice (no separate consent checkbox is required as the legal basis is contract performance / legitimate interest, not consent)

This satisfies the Art. 13 requirement to provide information "at the time personal data are obtained."

#### Scenario: Privacy summary shown on first activation — regular player
- **WHEN** a player (non-admin) clicks their first magic link and has not previously activated their account
- **THEN** the activation screen displays the privacy summary; after dismissal the player is redirected to `/:tenant_slug/` (the dashboard)

#### Scenario: Privacy summary shown on first activation — tenant admin
- **WHEN** a newly invited tenant admin clicks their first magic link
- **THEN** the activation screen displays the privacy summary; after dismissal the tenant admin is redirected to `/:tenant_slug/admin` with a welcome banner: *"Welcome! Start by setting up your league — configure your imprint and invite your first players."*

#### Scenario: Privacy summary not shown on subsequent logins
- **WHEN** an already-activated player authenticates via magic link
- **THEN** they are redirected directly to their usual landing page (dashboard for players, admin panel for tenant admins) without the privacy summary

### Requirement: Legal pages are linked from every page footer
Every page in the tenant application SHALL include a footer with links to `/:tenant_slug/imprint` and `/:tenant_slug/privacy`. The footer SHALL be visible on all pages including the login page.

#### Scenario: Footer present on login page
- **WHEN** an unauthenticated user visits `/:tenant_slug/login`
- **THEN** the footer with imprint and privacy links is visible

#### Scenario: Footer present on leaderboard
- **WHEN** an authenticated player views the leaderboard
- **THEN** the footer with imprint and privacy links is visible
