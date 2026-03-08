## ADDED Requirements

### Requirement: The application supports English and German as initial languages
All UI strings, error messages, and email templates SHALL be available in English (en) and German (de). English SHALL be the system-wide fallback when a string is missing in the active locale. Gettext SHALL be used as the translation framework.

#### Scenario: Missing translation falls back to English
- **WHEN** a UI string has no translation for the active locale
- **THEN** the English string is shown as fallback

### Requirement: Each player can set their preferred locale
Every player SHALL be able to set their preferred display language in their profile settings. The preference SHALL be stored in the `player_profiles` read model. Changes take effect immediately without requiring a page reload.

#### Scenario: Player sets locale preference
- **WHEN** a player selects a language in their profile settings
- **THEN** the UI immediately switches to that language and the preference is persisted

### Requirement: Locale is determined in priority order
The active locale SHALL be resolved in the following order:
1. Player's saved preference (if authenticated and set)
2. Browser `Accept-Language` header (parsed from the request)
3. System default: English (`en`)

#### Scenario: Authenticated player with saved preference
- **WHEN** an authenticated player with locale set to `de` loads any page
- **THEN** the page is rendered in German regardless of the browser language

#### Scenario: New unauthenticated user with German browser
- **WHEN** an unauthenticated user with `Accept-Language: de` visits the login page
- **THEN** the page is rendered in German

#### Scenario: Fallback to English
- **WHEN** a user's browser reports an unsupported locale and no preference is saved
- **THEN** the page is rendered in English

### Requirement: Each tenant has a configurable default locale
Tenant config SHALL include a `default_locale` setting (enum: `en` | `de`, default: `en`). The tenant default locale SHALL be used for:
- Invite emails sent before the recipient has a profile (magic link invites, invite link registrations)
- Any context where no user preference or browser locale is available

#### Scenario: Invite email sent in tenant default locale
- **WHEN** a tenant admin invites a new player by email and the tenant default locale is `de`
- **THEN** the invitation email is sent in German

#### Scenario: Tenant admin sets default locale
- **WHEN** a tenant admin updates `default_locale` in tenant config
- **THEN** all subsequent invite emails for that tenant use the new locale

### Requirement: All email notifications are sent in the recipient's locale
Email notifications SHALL be rendered in the recipient's preferred locale. If no preference is set, the tenant default locale SHALL be used.

#### Scenario: Notification email sent in user's locale
- **WHEN** a notification email is triggered for a player with locale `de`
- **THEN** the email is rendered and sent in German

#### Scenario: Notification email falls back to tenant default
- **WHEN** a notification email is triggered for a player with no saved locale preference
- **THEN** the email is rendered in the tenant's default locale

### Requirement: System-generated privacy notice is rendered in the active locale
The system-generated section of the privacy notice page SHALL be translated into all supported languages. The page SHALL render in the active locale following the standard locale detection order.

#### Scenario: Privacy notice renders in German for German-locale user
- **WHEN** a user with German locale visits `/:tenant_slug/privacy`
- **THEN** the system-generated section is displayed in German

### Requirement: Each player can set their preferred colour theme
Every player SHALL be able to choose between a light and dark colour theme in their profile settings. The preference SHALL be stored as a `theme` column in the `player_profiles` read model. The initial value SHALL be `system` (follow `prefers-color-scheme`). Changes take effect immediately without a page reload.

The available values are:
- `system` — follows the OS/browser `prefers-color-scheme` media query (default)
- `light` — always light theme
- `dark` — always dark theme

#### Scenario: Player sets dark theme
- **WHEN** a player selects "Dark" in their profile settings
- **THEN** the UI immediately switches to the dark theme and the preference is persisted

#### Scenario: Player uses system default
- **WHEN** a player's theme preference is `system`
- **THEN** the UI follows the browser `prefers-color-scheme` media query

### Requirement: New languages can be added by providing translation files
The system SHALL support adding new languages by providing a Gettext PO file for that locale. No code changes SHALL be required to activate a new language once its PO file is complete.

#### Scenario: New locale added via PO file
- **WHEN** a complete PO file for a new locale is added and the application is restarted
- **THEN** that locale becomes available as a selectable option in profile settings
