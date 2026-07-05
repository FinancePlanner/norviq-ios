# FinancePlan iOS (`financeplan`)

SwiftUI client for portfolio planning, stock research UI, expenses/budget views, and authenticated API access. It targets the StockPlan backend and shares DTOs with the server via **StockPlanShared**.

---

## Architecture

| Layer | Role |
|--------|------|
| **Views** | SwiftUI screens and sheets; composition and navigation. |
| **View models** | `ObservableObject` types (`@MainActor` where used) holding screen state and calling services. |
| **Services** | Protocol-oriented networking and domain orchestration (e.g. `StockServicing`, `AuthServicing`). |
| **API** | HTTP clients, endpoint descriptors, and Factory wiring for assets/profile where split out. |
| **DI** | [Factory](https://github.com/hmlongco/Factory) — `Container+AppFactories.swift` registers singletons (`stockService`, `authSessionManager`, `appEnvironment`, `windowSize`, …). |
| **Shared models** | **StockPlanShared** — Codable DTOs aligned with the backend (`StockResponse`, auth payloads, watchlist, etc.). |

**UI pattern:** MV-first hybrid: default to SwiftUI-native MV orchestration in views; keep MVVM where complex async/domain coordination warrants it.

- Refactor standard: `docs/engineering/swiftui-refactor-standard.md`
- Wave tracking: `docs/engineering/swiftui-refactor-wave1.md`

**Navigation:** `ContentView` gates **splash → login vs main**. After login, `HomeScreen` owns a `TabView` (Home, Portfolio, Expenses, Reports, Settings). Portfolio uses a nested segmented control (Holdings / Allocation / Watchlist). Stock detail is pushed via `NavigationStack` from portfolio rows.

**Session:** `SessionManager` (`ObservableObject`) exposes display username app-wide. `AuthSessionManager` + `UserDefaultsAuthSessionStore` persist tokens; `NotificationCenter` notifies on invalidation.

**Appearance:** `AppAppearance` (`@AppStorage`) drives `preferredColorScheme` from `NorviqaApp`. `AppTheme` centralizes semantic colors for light/dark.

---

## App entry & root flow

| File | Responsibility |
|------|----------------|
| `NorviqaApp.swift` | `@main` app; injects `SessionManager`, `AppEnvironment`, appearance. |
| `ContentView.swift` | Splash delay → restore session → `LoginScreen` or `HomeScreen` or `OnboardingImportFlow` (first-time stock import flag per user). |
| `Features/Launch/SplashScreen.swift` | Launch branding / transition. |

---

## Features (screens & view models)

### Home (`Features/Home/`)

| Item | Description |
|------|-------------|
| `HomeScreen.swift` | Main `TabView`: dashboard, portfolio root, expenses planner, expenses comparison (“Reports”), settings. Contains private dashboard cards (hero, trends, search, insights). |
| `AssetSearchViewModel.swift` | Search field state and asset search calls. |

### Portfolio (`Features/Portfolio/`)

| Item | Description |
|------|-------------|
| `PortfolioViewModel.swift` | Loads portfolio, CRUD helpers, allocation slice math, `isSaving` / `isDeletingStock`. |
| `PortfolioScreen.swift` | Holdings list, summary card, add/edit sheets, navigation to `StockDetailScreen`. |
| `PortfolioAllocationScreen.swift` | Cost-basis donut (Swift Charts), legend, share flow (render PNG + `ShareLink`). |

### Stocks (`Features/Stocks/`)

| Item | Description |
|------|-------------|
| `StockDetailScreen.swift` | Detail shell: tabs (Overview / Projections / Compare), share link, sheets for valuation and position edit. |
| `StockDetailsScreenViewModel.swift` | Loads details, history, news, valuation; peer comparison mock data; save position / delete position / valuation. |
| `StockInsightsViews.swift` | Large set of tab subviews: hero card, overview tab, projections, compare, history, news, valuation summary, etc. |
| `StockInsightsModels.swift` | Local models for insights/compare UI. |
| `EditStockPositionSheet.swift` | Shared sheet: shares, buy price, notes, save, delete with confirmation. |
| `EditStockValuationView.swift` | Valuation editor sheet. |
| `StockService.swift` | `StockServicing` implementation delegating to `StockHTTPClient`. |
| `StockDetails.swift` | Typealiases to shared DTOs. |
| `StockShareFormatter.swift` | Text snapshot for share sheet. |
| `StockValuationCard.swift`, `StockValuationDraft.swift` | Valuation UI helpers. |
| `Watchlist/WatchlistTab.swift` | Watchlist UI segment. |
| `Watchlist/WatchlistViewModel.swift` | Watchlist load/mutate. |

### Expenses (`Features/Expenses/`)

| Item | Description |
|------|-------------|
| `ExpensesPlannerScreen.swift` | Budget planner UI. |
| `ExpensesComparisonScreen.swift` | Comparison / “Reports” style charts for expenses. |
| `BudgetPlannerViewModel.swift` | Planner state and logic. |
| `BudgetPlannerModels.swift` | Planner model types. |

### Auth (`Features/Auth/`)

| Item | Description |
|------|-------------|
| `LoginScreen.swift` | Sign-in / sign-up UI; terms & privacy use `ExternalBrowserLinkSheet`. |
| `LoginViewModel.swift` | Form validation and auth calls. |
| `AuthService.swift` | `AuthServicing` implementation. |
| `AuthSessionManager.swift` | Login, refresh, logout, restore. |
| `SecureStringStore.swift`, `JWTTokenInspector.swift` | Token storage / parsing helpers. |
| `AuthValidation.swift` | Input rules. |

### Onboarding (`Features/Onboarding/`)

| Item | Description |
|------|-------------|
| `OnboardingImportFlow.swift` | Wrapper flow for first import. |
| `InitialStockImportScreen.swift` | Entry to import UX. |
| `OnboardingHeader.swift` | Shared header. |
| `OnboardingImportViewModel.swift`, `CSVImportViewModel.swift`, `ManualImportViewModel.swift` | Import path state machines. |

### User profile (`Features/UserProfile/`)

| Item | Description |
|------|-------------|
| `UserProfileView.swift`, `EditProfileView.swift` | Profile display and edit. |
| `UserProfileViewModel.swift`, `UserProfileService.swift`, `UserProfile.swift` | Profile loading/updating. |

---

## Components (`Components/`)

Reusable UI building blocks:

| File | Purpose |
|------|---------|
| `GlassCard.swift` | Frosted card container used across dashboard and lists. |
| `MeshGradientBackground.swift` | Full-screen mesh gradient (e.g. dashboard). |
| `FormComponents.swift` | Sheet header, form cards, rows, text fields, dividers, bottom action bar, error banner, info tags. |
| `AddPositionSheet.swift` | Create holding. |
| `AddWatchlistSheet.swift` | Add watchlist item. |
| `AppTopBar.swift` | Top bar / profile affordances. |
| `GlowingButton.swift` | Accent button style. |
| `ToastBanner.swift` | Transient messages. |
| `UserMenuDrawer.swift` | User menu presentation. |

---

## API layer (`API/`)

| Area | Files |
|------|--------|
| **Stocks** | `Stocks/StockHTTPClient.swift`, `Stocks/StockEnpoints.swift` — authenticated requests, endpoints. |
| **Auth** | `Auth/AuthHTTPClient.swift`, `Auth/AuthEndpoints.swift`. |
| **User profile** | `UserProfile/UserProfileHTTPClient.swift`, `UserProfileEndpoints.swift`, `Container+UserProfileFactories.swift`. |
| **Assets** | `Assets/AssetSearchService.swift`, `Container+AssetSearchFactories.swift`. |

**Environment:** `AppEnvironment.swift` / `AppEnvironmentManager` selects API base URL and related config.

---

## Typography & theme

| Path | Role |
|------|------|
| `Typography/` | `Typography`, `TypographyStyle`, `View+Typography`, font scheme (e.g. Avenir). |
| `AppTheme.swift` | Colors, `AppAppearance` enum, avatar gradients. |

---

## Utilities (`Utilities/`)

| File | Role |
|------|------|
| `ExternalBrowserLinkSheet.swift` | SwiftUI-only prompt to open URLs in the system browser (`openURL`). |
| `Utility.swift` | Small helpers (e.g. `Double.currency`). |
| `AppSensoryFeedback.swift` | Haptics / feedback hooks for views. |
| `Debouncer/` | Debounced bindings / typing. |
| `FrameReader/` | Size preference keys for layout. |
| `ImagePicker.swift`, `SelectedMedia.swift`, `ImageType.swift`, `Icon.swift` | Media / asset helpers. |
| `URLDetector.swift`, `ChannelSlug.swift` | Text / URL helpers. |

Other top-level helpers: `DateUtils.swift`, `Constants.swift`, `SchemeEnvironment.swift`, `WindowSizeSyncView.swift`.

---

## Backend

The HTTP API this app calls is implemented by **StockPlanBackend**, in the same monorepo:

- **Path (from repo root `StockProject/`):** [`StockPlanBackend/`](../../StockPlanBackend) — Swift server, routes, and `Sources/StockPlanBackend/openapi.yaml` for the contract.

**Configured base URLs** (see `financeplan/AppEnvironment.swift`):

| Environment | API base | WebSocket base |
|-------------|----------|----------------|
| **local** | `http://localhost:8080` | `ws://localhost:8080/ws` |
| **dev** | `https://dev-api.norviqa.io` | `wss://dev-api.norviqa.io/ws` |
| **production** | `https://api.norviqa.io` | `wss://api.norviqa.io/ws` |

Run the backend locally (see `StockPlanBackend/README.md` and `docker-compose.yml`) when using the **local** environment.

---

## Shared models dependency (StockPlanShared)

DTOs and shared types come from **StockPlanShared** (norviq-shared package), e.g. `StockResponse`, `StockRequest`, watchlist types, bulk import, valuation requests.

Configure the Swift package in Xcode (`financeplan.xcodeproj`). Version policy (example): `0.1.0` up to next major.

If packages fail to resolve:

1. Ensure the remote repo has a matching semver tag.
2. **File → Packages → Reset Package Caches**
3. **File → Packages → Resolve Package Versions**

---

## Tests

- `financeplanTests/` — unit tests for view models (e.g. `PortfolioViewModelTests`, `StockDetailsViewModelTests`, `BudgetPlannerViewModelTests`, services).
- `ContentView` supports launch arguments for UI tests (e.g. skip splash, inject tokens, reset session); see `ContentView.swift` `init`.

---

## Project layout (summary)

```
financeplan/
├── financeplan/
│   ├── NorviqaApp.swift
│   ├── ContentView.swift
│   ├── SessionManager.swift
│   ├── Container+AppFactories.swift
│   ├── AppTheme.swift, AppEnvironment.swift
│   ├── Features/          # Screens by domain
│   ├── Components/      # Reusable SwiftUI
│   ├── API/               # HTTP + Factory extensions
│   ├── Typography/
│   └── Utilities/
├── financeplanTests/
├── financeplanUITests/
├── Info.plist
└── LaunchScreen.storyboard
```

---

## Conventions

- Prefer **SwiftUI** for UI; avoid UIKit bridges unless required by platform APIs.
- For refactors, follow `swiftui-view-refactor` rules and keep PRs behavior-preserving.
- Default to MV; retain view models only when they own complex async/domain workflows.
- New screens: place under `Features/<Domain>/`, inject dependencies via **Factory** or `EnvironmentObject` where already established (e.g. portfolio `PortfolioViewModel` shared across Holdings and Allocation tabs).
- Align request/response shapes with **StockPlanShared** and the StockPlan backend OpenAPI.
