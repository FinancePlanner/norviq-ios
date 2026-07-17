# Dual-bundle: prod + TestFlight side-by-side

Two App Store Connect apps share one codebase:

| Track | Bundle ID | Display name | Scheme | Config | Ship path |
|---|---|---|---|---|---|
| Prod | `facorreia.financeplan` | Norviq | `financeplan` | Release | `fastlane release` / App Store |
| Beta | `facorreia.financeplan.beta` | Norviq Beta | `Norviqa TestFlight Dev` | Beta | `fastlane beta` (CI on `main`) |

iOS installs them as **two separate apps** on the same phone.

## One-time Apple setup (you)

1. **Developer portal** → register App ID `facorreia.financeplan.beta` with the same capabilities as prod (Push, Sign in with Apple, Associated Domains, IAP as needed).
2. **App Store Connect** → New App → pick that bundle ID → name e.g. `Norviq Beta` → add yourself to Internal Testing.
3. **Match profiles** (once, with ASC + match secrets):

   ```bash
   cd norviq-ios/financeplan
   bundle exec fastlane seed_signing
   # or:
   bundle exec fastlane match appstore --readonly false
   ```

   Matchfile already lists both identifiers.
4. Optional: create a **Google iOS OAuth client** for the beta bundle if Google reverse-scheme collisions matter. Until then beta reuses the prod Google client reverse scheme.
5. **Backend allowlist** must include beta custom schemes (already expanded for `norviqa://…`; add if missing):

   - `norviqa-beta://oauth/callback`
   - `norviqa-beta://oauth/broker-callback`

## Build settings (in repo)

- `APP_DISPLAY_NAME` / `OAUTH_CALLBACK_SCHEME` differ per config.
- Beta uses `financeplan/Norviqa.Beta.entitlements`.
- Info.plist interpolates `$(APP_DISPLAY_NAME)` and `$(OAUTH_CALLBACK_SCHEME)`.

## Local run

- Prod-like: scheme **financeplan** (Debug/Release).
- Side-by-side beta: scheme **Norviqa TestFlight Dev** → archives/runs **Beta** config.

## CI

Push to `main` → `release.yml` → `fastlane beta` → uploads only to **`facorreia.financeplan.beta`** TestFlight.

App Store prod is **manual** (`workflow_dispatch` / `fastlane release`).
