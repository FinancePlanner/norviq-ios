# FinancePlan iOS App Overview

## Purpose
This document explains how the app is structured, how navigation currently works, and how the project is built.

## Repository Structure

```text
financeplan/
├── financeplan/                # App target source code
│   ├── API/                    # Networking layer (currently auth endpoints/client)
│   ├── Features/               # Feature modules (auth UI + view model + service)
│   ├── Typography/             # Font/typography abstractions
│   ├── Utilities/              # Reusable UI/system helpers
│   ├── Documentation/          # Project docs (this file + auth architecture)
│   ├── Assets.xcassets/        # App assets
│   ├── AppEnvironment.swift    # Environment definitions (local/dev/production)
│   ├── Constants.swift         # Constants + environment manager
│   ├── Container+AppFactories.swift # DI registrations
│   ├── ContentView.swift       # Root UI composition + app flow switch
│   └── FinPlannerApp.swift     # App entry point (@main)
├── financeplanTests/           # Unit tests
├── financeplanUITests/         # UI tests
└── financeplan.xcodeproj/      # Xcode project + SwiftPM package metadata
```

Notes:
- `financeplan/Components`, `financeplan/Extensions`, and `financeplan/Services` currently exist as organizational folders but are empty.
- `financeplan/financeplanApp.swift` exists as a second app struct but does not have `@main`; `FinPlannerApp.swift` is the active entry point.

## Runtime Architecture

### 1) App entry and lifecycle
- Entry point is `financeplan/FinPlannerApp.swift` (`@main`).
- `FinPlannerApp` bootstraps `ContentView` and injects `AppDelegate`.
- `AppDelegate` currently configures push notification delegation and logs APNs events.

### 2) Dependency injection
- DI is handled via Factory (`Container.shared`).
- Registrations are in `financeplan/Container+AppFactories.swift`:
  - `AppEnvironmentManager`
  - `WindowSize`
  - `AuthServicing` implemented by `AuthService`
  - `AuthSessionStoring` implemented by `UserDefaultsAuthSessionStore`

### 3) Environment/configuration
- Environment values live in `financeplan/AppEnvironment.swift`.
- `AppEnvironmentManager` resolves active environment in this order (`financeplan/Constants.swift`):
  1. runtime env var `FINPLANNER_ENVIRONMENT`
  2. generated `SchemeEnvironment.value`
  3. persisted user default `environment`
  4. fallback default (`dev` in debug, `production` in release)
- Auth requests use `environmentManager.current.apiBaseUrl`.

### 4) Feature layering (auth)
- API layer: `financeplan/API/Auth/*`
  - Endpoint structs + `AuthHTTPClient`
- Service layer: `financeplan/Features/Auth/AuthService.swift`
  - Converts UI input into shared DTOs from `StockPlanShared`
- Presentation layer:
  - `financeplan/Features/Auth/LoginViewModel.swift`
  - `financeplan/Features/Auth/LoginScreen.swift`
  - `financeplan/Features/Onboarding/InitialStockImportScreen.swift` (mandatory first-login step)
- Session persistence: `UserDefaultsAuthSessionStore`

See `financeplan/Documentation/auth_arch.md` for auth details.

### 5) Shared UI and helper infrastructure
- `financeplan/Typography/*`: consistent typography API (Avenir-backed).
- `financeplan/Utilities/FrameReader/*`: geometry/size readers used by UI layout.
- `financeplan/Utilities/ImagePicker.swift`: image/video picker bridge.
- `financeplan/Utilities/SafariView.swift`: in-app Safari wrapper.
- `financeplan/WindowSizeSyncView.swift`: keeps window metrics in shared state.

## Navigation Model

The app currently uses state-driven root switching, not `NavigationStack` routing.

### Root flow (`financeplan/ContentView.swift`)
1. App starts with `SplashScreen` for ~2 seconds.
2. After splash:
   - if `sessionStore.authToken` is present and current user has not completed initial stock import -> show mandatory `InitialStockImportScreen`
   - if `sessionStore.authToken` is present and current user has completed import -> show `HomeScreen`
   - else -> show `LoginScreen`
3. Successful login toggles `isAuthenticated = true`; root then enforces the per-user first-login import gate before home.
4. Logout clears stored tokens and toggles `isAuthenticated = false`.

Auth behavior details:
- Signup no longer auto-authenticates; success returns user to login with a success message.
- Login authenticates and enters the mandatory first-login stock-import gate.
- Logout calls backend logout with refresh token, then clears local tokens.

### Auth screen interactions (`financeplan/Features/Auth/LoginScreen.swift`)
- Login/signup mode is toggled in place (same screen).
- Forgot password is displayed as an overlay modal view.
- Terms and Privacy open with `.sheet` using `SafariView`.
- Environment selector appears in a `.confirmationDialog`.

Current implication:
- Navigation is intentionally lightweight and local-state based.
- First-login stock import is a required gate and cannot be bypassed.
- There is no global route enum/router yet.

## Build System and Dependencies

### Xcode project
- Project file: `financeplan.xcodeproj/project.pbxproj`.
- Targets:
  - `financeplan` (app)
  - `financeplanTests` (unit tests)
  - `financeplanUITests` (UI tests)
- Build settings highlights:
  - iOS deployment target: `26.2`
  - Swift version: `5.0`
  - default actor isolation: MainActor (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
  - app bundle id: `facorreia.financeplan`

### Swift Package Manager dependencies
Defined in project metadata and locked in `financeplan.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

Primary packages currently linked to the app target:
- AnyAPI
- Alamofire
- Factory
- Kingfisher
- SwiftyCrop
- StockPlanShared (from FinanceShared)
- EntityStore
- BetterCodable
- Drops
- Lottie
- MarkdownUI
- Sentry

### App configuration files
- `Info.plist`: app metadata, ATS exceptions, DSN/key entries, UI style.
- `financeplan/FinPlanner.entitlements`: associated domains and push entitlement.
- `financeplan/SchemeEnvironment.swift`: generated file used in environment resolution.

## How to Build and Test

From repository root:

```bash
xcodebuild -project financeplan.xcodeproj -scheme financeplan -destination 'generic/platform=iOS Simulator' build
```

Run all unit tests:

```bash
xcodebuild -project financeplan.xcodeproj -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' test
```

Run only auth client tests:

```bash
xcodebuild -project financeplan.xcodeproj -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:financeplanTests/AuthHTTPClientTests test
```

## Testing Coverage Snapshot
- Auth networking and error mapping: `financeplanTests/AuthHTTPClientTests.swift`
- Auth validation: `financeplanTests/AuthValidationTests.swift`
- Login view model flow and token persistence: `financeplanTests/LoginViewModelTests.swift`
- Basic UI launch/auth appearance checks: `financeplanUITests/financeplanUITests.swift`

## Current Architectural State
- The codebase is a clean, modular foundation centered on authentication flow.
- App-level navigation is simple and deterministic.
- API layer is endpoint-driven and testable.
- Structure is ready for additional features/modules to be added under `Features/` with corresponding API and service layers.
