# Norviqa iOS SwiftUI Client Study Guide

## Implemented Pre-Login Paywall & Privacy Flow (2026-04-24)

Main work:
- Added a pre-login privacy screen (`PrivacyWelcomeScreen`) highlighting data ownership and security.
- Added a pre-login paywall screen (`PreLoginPaywallScreen`) allowing anonymous users to start a 7-day free trial on the Pro annual plan.
- Configured Amplitude unified SDK for iOS analytics, initialized via DI (`AnalyticsService`), currently tracking "App Launched".
- Set up local StoreKit testing (`Products.storekit`) in Xcode with `pro_weekly`, `pro_monthly`, and `pro_annual` to bypass App Store Connect for local simulator testing.
- Updated `BillingManager` to support anonymous RevenueCat initialization and purchases, aliasing to the user ID upon login/signup.

Key files:
- `financeplan/Products.storekit`
- `financeplan/Features/Analytics/AnalyticsService.swift`
- `financeplan/API/Analytics/Container+AnalyticsFactories.swift`
- `financeplan/Features/Auth/PrivacyWelcomeScreen.swift`
- `financeplan/Features/Auth/PreLoginPaywallScreen.swift`
- `financeplan/ContentView.swift`
- `financeplan/NorviqaApp.swift`
- `financeplan/Features/UserProfile/BillingManager.swift`

## Implemented Broker IBKR Sync Integration (2026-04-23)

Main work:
- iOS Portfolio import sheet now has IBKR connect / sync / disconnect.
- iOS broker client starts browser flow with `ASWebAuthenticationSession`, then reloads Portfolio.
- Backend has broker connect-start endpoint, public callback, sync endpoint, disconnect endpoint.
- Backend sync pulls IBKR accounts/positions from existing IBKR gateway base URL and upserts imported holdings into Portfolio.
- Disconnect clears broker credential state and keeps imported holdings.

Key files:
- `financeplan/API/Brokers/BrokerEndpoints.swift`
- `financeplan/API/Brokers/BrokerHTTPClient.swift`
- `financeplan/API/Brokers/CsvImportFlowViewModel.swift`
- `financeplan/Features/Onboarding/BrokerService.swift`
- `financeplan/Features/Portfolio/PortfolioCSVImportSheet.swift`
- `financeplanTests/BrokerServiceTests.swift`
- `financeplanTests/PortfolioCSVImportViewModelTests.swift`
- `StockPlanBackend/Sources/StockPlanBackend/Broker/BrokerController.swift`
- `StockPlanBackend/Sources/StockPlanBackend/Broker/BrokersService.swift`
- `StockPlanBackend/Sources/StockPlanBackend/Broker/IBKRBrokerIntegration.swift`
- `StockPlanBackend/Sources/StockPlanBackend/Auth/AuthController.swift`
- `StockPlanBackend/Sources/StockPlanBackend/Models/BrokerConnection.swift`
- `StockPlanBackend/Sources/StockPlanBackend/Models/BrokerOAuthFlow.swift`
- `StockPlanBackend/Sources/StockPlanBackend/Migrations/AddBrokerOAuthFlowAndConnectionMetadata.swift`

Build:
- iOS xcodebuild ... build passed.
- Backend swift build passed.

Important caveat:
- Repo package wiring uses older external shared package for broker DTOs. I kept iOS and backend broker-flow DTO additions local where needed so feature builds now without waiting on shared package publish/update.

What acceptance now does:
- Connect IBKR account: yes, from Portfolio import sheet.
- Holdings auto-import into Portfolio: yes, callback triggers sync inline.
- Sync button refreshes positions: yes.
- Disconnect revokes token: best-effort local disconnect only. Current backend has no real IBKR token revoke adapter in repo, so it clears stored broker auth state and marks disconnected.

Not run:
- Full test suites.
- Real end-to-end IBKR live session test. Need actual `IBKR_API_BASE_URL` session up for that.

## Implemented Billing MVP Slice (2026-04-23)

- Backend: added pro plan compatibility, Pro gates, Pro limits, RevenueCat /v1/billing/restore, REVENUECAT_API_KEY production requirement.
- iOS: added RevenueCat package, API-key plist hook, BillingHTTPClient, BillingManager, custom SwiftUI Pro paywall, Settings subscription rows, restore/manage actions, Pro gating in reports, stock detail premium tabs/actions, portfolio alert action.
- Shared DTOs: added isPro compatibility while preserving isPremium.

Verified:
- financeplan iOS simulator build: passed.
- StockPlanShared swift test: passed, 23 tests.
- StockPlanBackend swift build: blocked by pre-existing broker/shared mismatch:
  - BrokerConnectStartRequest missing in StockPlanShared
  - BrokerConnectStartResponse missing in StockPlanShared

Still needs external config:
- Backend env: REVENUECAT_API_KEY
- iOS build setting: REVENUECAT_IOS_API_KEY
- RevenueCat: entitlement pro, products pro_monthly, pro_annual
- App Store Connect: subscription group + 14-day annual trial.

## Purpose

This document is a study guide for the SwiftUI client project. It explains the app architecture, the important Swift and SwiftUI structures, local persistence, networking, concurrency, UI composition, and the major feature modules.

Use it as a map when reading the codebase. The app is useful to study because it is not a tiny sample project: it has authenticated API calls, local SwiftData caching, token refresh, feature view models, charts, settings, onboarding, push notifications, reports, and reusable design components.

For feature ownership and data-flow boundaries, read `source-of-truth.md` alongside this guide. That file states which features are API-backed, which SwiftData rows are cache-only, and where mocks are allowed.

## Current App Shape

Norviqa is an iOS finance app with two main product areas:

- personal finance: expenses, budgets, recurring spend, reports, dashboard insights
- investing: portfolio holdings, allocation, watchlist, stock research, valuations, market data

The client is a SwiftUI app backed by a Vapor API. The app uses:

- SwiftUI for UI and app lifecycle
- SwiftData for local cache and offline-style expense writes
- `Factory` for dependency injection
- `URLSession` through feature HTTP clients
- `async/await` for networking and view-model loading
- `NotificationCenter` for cross-feature refresh events
- Swift Charts for finance visualizations
- Sentry for observability
- shared DTOs from `StockPlanShared`

## Recent Data-Isolation Changes

The local cache now has explicit user ownership. This matters because the same simulator or physical device can log into multiple accounts.

The bug fixed here was:

- a new user could see stale portfolio, allocation, recent spend, and budget data from a previous signed-in user
- backend responses were user-scoped, but local SwiftData rows were not
- Portfolio and Expenses views read every local row from SwiftData
- some UI showed fake positive portfolio trends for an empty account

The fix added:

- `ownerUserId` to local SwiftData models
- `LocalCacheScope.currentOwnerUserId`
- user-scoped local fetches in Portfolio, Allocation, Watchlist, Expenses, and sync code
- cleanup/ignore behavior for legacy unowned local rows
- no automatic budget snapshot creation while loading a blank account
- zero-state portfolio chart behavior
- neutral empty portfolio trend copy instead of fake green gains
- more stable empty-state card heights

Study these files for the fix:

- `Models/Local/LocalCacheScope.swift`
- `Models/Local/SDPortfolioStock.swift`
- `Models/Local/SDWatchlistItem.swift`
- `Features/Expenses/ExpensesSwiftDataModels.swift`
- `Features/Expenses/ExpensesSyncManager.swift`
- `Features/Expenses/BudgetPlannerViewModel.swift`
- `Features/Portfolio/PortfolioViewModel.swift`
- `Features/Portfolio/PortfolioScreen.swift`
- `Features/Portfolio/PortfolioAllocationScreen.swift`
- `Features/Stocks/Watchlist/WatchlistViewModel.swift`
- `Features/Stocks/Watchlist/WatchlistTab.swift`

## Repository Layout

The app target lives under:

```text
financeplan/
├── API/                  # HTTP clients, endpoints, feature networking factories
├── Components/           # reusable SwiftUI components
├── Documentation/        # architecture and implementation notes
├── Extensions/           # reusable SwiftUI compatibility/helper modifiers
├── Features/             # feature modules
├── Models/Local/         # SwiftData models and shared ModelContainer
├── Typography/           # typography system
├── Utilities/            # generic helpers, parsers, image/chart utilities
├── AppEnvironment.swift
├── AppLanguage.swift
├── AppTheme.swift
├── Constants.swift
├── ContentView.swift
├── NorviqaApp.swift
└── SessionManager.swift
```

Feature folders usually follow this shape:

```text
Features/<Feature>/
├── <Feature>Screen.swift
├── <Feature>ViewModel.swift
├── <Feature>Service.swift
└── <Feature>Models.swift
```

The app is not perfectly uniform, but the common pattern is:

```text
SwiftUI View -> ViewModel -> Service -> HTTP Client -> Endpoint -> API
```

## App Lifecycle

The entry point is `NorviqaApp`.

Important structures:

- `@main struct NorviqaApp: App`
- `WindowGroup`
- `ContentView`
- `.modelContainer(sharedModelContainer)`
- `.environmentObject(sessionManager)`
- `.preferredColorScheme(...)`
- `.tint(...)`
- `@UIApplicationDelegateAdaptor(PushNotificationsAppDelegate.self)`

`NorviqaApp` is responsible for global app setup:

- creates the root `SessionManager`
- injects SwiftData's shared model container
- injects session state into SwiftUI's environment
- applies stored language and appearance preferences
- wires push-notification delegate behavior
- applies the current app environment identity

`ContentView` is the root flow controller. It chooses which major experience to show:

- splash
- login/signup
- onboarding/import flow
- authenticated main app
- locked app state when security lock is active

This is a SwiftUI state-machine pattern: instead of imperatively pushing root controllers, the root view derives the visible app flow from state.

## Environment And Configuration

Important files:

- `AppEnvironment.swift`
- `Constants.swift`
- `SchemeEnvironment.swift`
- `Container+AppFactories.swift`

`AppEnvironment` contains:

- title
- REST API base URL
- websocket base URL

The supported environments are:

- local
- dev
- production

Environment selection can come from:

- `NORVIQA_ENVIRONMENT`
- Xcode scheme configuration
- persisted user defaults
- build defaults

`AppEnvironmentManager` uses modern Swift observation with `@Observable`. This is different from `ObservableObject`; SwiftUI can track property reads more precisely.

## Dependency Injection

The app uses `Factory`.

Common registration pattern:

```swift
extension Container {
  var stockService: Factory<StockServicing> {
    self { StockService(...) }
  }
}
```

Important injection styles used in the app:

- `@InjectedObservable(\Container.appEnvironment)` for observable app-wide state
- `@StateObject` for view-owned view models
- direct `Container.shared.someService()` for service construction inside view models
- feature-specific `Container+...Factories.swift` files for modular dependencies

Study:

- `Container+AppFactories.swift`
- `API/Expenses/Container+ExpensesFactories.swift`
- `API/Dashboard/Container+DashboardFactories.swift`
- `API/MarketData/Container+MarketDataFactories.swift`
- `API/UserProfile/Container+UserProfileFactories.swift`

The main benefit is testability. View models can receive mock services, while production uses real services from the container.

## State Management

The app uses several SwiftUI state tools. Study where each appears.

### `@State`

Used for value state owned by a view:

- selected tab
- selected segment
- sheet visibility
- selected item for a sheet
- temporary form input
- animation flags
- chart selection

Examples:

- `HomeScreen`
- `PortfolioScreen`
- `ExpensesComparisonScreen`
- `LoginScreen`

### `@StateObject`

Used when a view owns a reference model lifecycle:

- `BudgetPlannerViewModel`
- `ReportsViewModel`
- `PortfolioViewModel`
- `LoginViewModel`
- `BadgesViewModel`

### `@ObservedObject`

Used when a parent owns the object and a child observes it:

- `ExpensesPlannerScreen(viewModel:)`
- `WatchlistTab(viewModel:)`
- settings/profile subviews

### `@EnvironmentObject`

Used for broad app-level or feature-root shared state:

- `SessionManager`
- `PortfolioViewModel` inside portfolio screens

### `@Environment`

Used for SwiftUI environment values:

- `colorScheme`
- `dismiss`
- `modelContext`
- `openURL`
- locale-dependent rendering

### `@AppStorage`

Used for small persisted preferences:

- app language
- app appearance
- reports dashboard card preferences

### `@Query`

Used to read SwiftData collections directly in SwiftUI views:

- portfolio holdings
- allocation holdings
- watchlist rows

Important rule in this project: raw `@Query` rows must be filtered by `LocalCacheScope` before rendering, because the shared model container can contain rows for multiple users.

## SwiftData Architecture

Important files:

- `Models/Local/SharedModelContainer.swift`
- `Models/Local/LocalCacheScope.swift`
- `Models/Local/SDPortfolioStock.swift`
- `Models/Local/SDWatchlistItem.swift`
- `Features/Expenses/ExpensesSwiftDataModels.swift`
- `Features/Expenses/ExpensesSyncManager.swift`

The shared model container includes:

- `SDPortfolioStock`
- `SDWatchlistItem`
- `LocalExpense`
- `LocalBudgetSnapshot`
- `LocalBudgetPlanItem`
- `LocalExpenseCategory`
- `LocalRecurringTemplate`
- `OfflineSyncAction`

### Local ownership

Most local models now include:

```swift
var ownerUserId: String?
```

Use:

```swift
LocalCacheScope.currentOwnerUserId
LocalCacheScope.isOwnedByCurrentUser(...)
```

This prevents cross-account local data leakage.

### Portfolio local model

`SDPortfolioStock` stores cached holdings:

- `id`
- `ownerUserId`
- `symbol`
- `shares`
- `buyPrice`
- `buyDate`
- `notes`
- `category`
- `portfolioListId`
- `lastSyncedAt`

`SwiftDataPortfolioLocalStore` reconciles API portfolio responses into SwiftData. It:

- deletes stale rows for the current user/list
- updates matching rows
- inserts new rows
- ignores or deletes legacy unowned rows

### Watchlist local model

`SDWatchlistItem` stores cached watchlist items:

- `id`
- `ownerUserId`
- `symbol`
- `note`
- `status`
- `nextReviewAt`
- `watchlistListId`
- `lastSyncedAt`

It follows the same current-user scoping pattern as portfolio.

### Expenses local models

Expense/budget local models include:

- `LocalExpense`
- `LocalBudgetSnapshot`
- `LocalBudgetPlanItem`
- `LocalExpenseCategory`
- `LocalRecurringTemplate`
- `OfflineSyncAction`

`ExpensesSyncManager` pulls from the API and updates SwiftData. It also pushes pending offline actions.

The sync flow:

```text
Expenses API -> ExpensesSyncManager.pullLatestData -> SwiftData rows -> BudgetPlannerViewModel.load -> SwiftUI screens
```

For offline-style local writes:

```text
BudgetPlannerViewModel.recordExpenseAndWait
-> insert LocalExpense
-> insert OfflineSyncAction
-> update in-memory activities
-> pushPendingActions
-> API create/update/delete
```

The app intentionally does not create budget data during a plain read/load. A blank account remains blank until the user explicitly creates budget or expense data.

## Networking Architecture

Networking is feature-specific. The common shape is:

```text
Endpoint type -> HTTP client -> Service -> ViewModel
```

Important endpoint folders:

- `API/Auth`
- `API/Stocks`
- `API/Expenses`
- `API/Dashboard`
- `API/MarketData`
- `API/UserProfile`
- `API/Notifications`
- `API/Badges`
- `API/Goals`

### Endpoint pattern

Endpoint structs usually define:

- path
- HTTP method
- request body
- query items
- expected response type

This keeps URL construction and response decoding out of views.

### HTTP clients

Examples:

- `AuthHTTPClient`
- `StockHTTPClient`
- `ExpensesHTTPClient`
- `DashboardHTTPClient`
- `MarketDataHTTPClient`
- `UserProfileHTTPClient`

HTTP clients usually:

- build a `URLRequest`
- attach auth headers when needed
- run `URLSession.data(for:)`
- validate status codes
- decode API envelopes or DTOs
- map server errors to typed client errors
- log useful debug info

### Service layer

Services hide networking details from view models.

Examples:

- `AuthService`
- `StockService`
- `ExpensesService`
- `DashboardService`
- `MarketDataService`
- `UserProfileService`
- `ActivityService`

Services often handle:

- current environment base URL
- auth token retrieval
- session invalidation on `401`
- retry or fallback behavior
- domain-friendly method names

## Authentication And Session Management

Important files:

- `Features/Auth/AuthService.swift`
- `Features/Auth/AuthSessionManager.swift`
- `Features/Auth/LoginViewModel.swift`
- `Features/Auth/LoginScreen.swift`
- `Features/Auth/SignInView.swift`
- `Features/Auth/SignUpView.swift`
- `Features/Auth/VaultMFAVerificationView.swift`
- `Features/Auth/VaultForgotPasswordView.swift`
- `Features/Auth/SocialAuthProvider.swift`
- `Features/Auth/SocialAuthButton.swift`
- `Features/Auth/SocialAuthSection.swift`
- `Features/Auth/VaultTextField.swift`
- `Features/Auth/PasswordStrengthMeter.swift`
- `Features/Auth/NorviqaLogo.swift`
- `Features/Auth/VaultPlatinumCard.swift`
- `Features/Auth/AuthFooter.swift`
- `Features/Auth/SecureStringStore.swift`
- `Features/Auth/JWTTokenInspector.swift`
- `Features/Auth/OAuthWebAuthenticator.swift`
- `API/Auth/AuthHTTPClient.swift`

### Auth storage

`UserDefaultsAuthSessionStore` stores:

- auth token
- refresh token
- token expirations
- current user id
- current username
- login/signup preference
- onboarding import completion by user id

Tokens are stored through `SecureStringStore` where possible. User defaults are used for simple metadata.

### Auth session manager

`AuthSessionManager` handles:

- restoring a session on launch
- checking access token expiry
- refreshing with the refresh token
- invalidating the session
- broadcasting invalidation notifications

Concurrency detail: refresh requests are deduplicated with a shared `Task` protected by a lock. This prevents several API calls from all refreshing the token at the same time.

### OAuth

OAuth sign-in uses:

- backend OAuth start endpoint
- `OAuthWebAuthenticator`
- callback URL parsing
- backend OAuth exchange endpoint

The API now supports linking Google, Apple, and X identities to an existing account when the provider returns the same verified email.

### Auth UI Architecture

The auth screens were refactored from a single 1074-line `LoginScreen.swift` into focused, single-responsibility views:

- `LoginScreen` — root container with `MeshGradientBackground`, sheet presentation, and environment switching
- `SignInView` — email/password form with `GlassCard`, social auth, and password visibility toggle
- `SignUpView` — registration form with username, email, password strength meter, confirm password, and date-of-birth picker
- `VaultMFAVerificationView` — 6-digit code entry sheet
- `VaultForgotPasswordView` — email-based password reset flow

Shared auth components:

- `VaultTextField` — reusable labeled text field with icon, secure mode, focus ring, and glass-styled background
- `SocialAuthButton` / `SocialAuthSection` — Apple, Google, X OAuth buttons with visible text labels
- `PasswordStrengthMeter` — 5-bar indicator with color + icon fallback for `accessibilityDifferentiateWithoutColor`
- `NorviqaLogo` — branded logo with shadow
- `VaultPlatinumCard` — marketing value proposition card
- `AuthFooter` — privacy, terms, help, and environment links

Design system alignment:

- All auth screens now use `AppTheme.Colors` instead of the old hardcoded `VaultColors` dark-only palette
- Background is `MeshGradientBackground` to match Home and Portfolio
- Form containers use `GlassCard` with `.appGlassEffect` for liquid-glass compatibility
- Primary actions use `.buttonStyle(.glassProminent)` with `AppTheme.Colors.tint`
- Typography uses semantic Dynamic Type (`.largeTitle`, `.headline`, `.subheadline`, `.caption`) instead of fixed sizes

Accessibility improvements:

- Social auth buttons show visible text (not just icons) for VoiceOver and HIG compliance
- Password visibility toggles use `Button("Show password", systemImage: "eye.fill")` with `.labelStyle(.iconOnly)`
- Password strength shows an icon when `.accessibilityDifferentiateWithoutColor` is enabled
- `DatePicker` overlay hack replaced with a proper sheet for date-of-birth selection
- All tap targets meet the 44×44 pt minimum

## Concurrency Patterns

The codebase is mostly `async/await`.

Patterns to study:

- `@MainActor` view models
- `.task { await viewModel.load() }`
- `.refreshable { await viewModel.load(force: true) }`
- `async let` for parallel independent requests
- `Task { ... }` for fire-and-forget UI actions
- cancellation-tolerant UI loading
- `defer` to reset loading flags
- lock-protected token refresh state

Examples:

- `DashboardRoot.loadContent()` loads metrics, insights, activity, focus points, and budget in parallel.
- `BudgetPlannerViewModel.load()` pulls API data, reads SwiftData, maps summaries, and fetches reports.
- `ReportsViewModel.load()` fetches report overview and partner data.
- `AuthSessionManager.validAccessToken()` deduplicates refresh.

Important style:

- UI mutation happens on main actor.
- Services and HTTP clients perform async I/O.
- View bodies do not perform networking directly.

## Cross-Feature Refresh

The app uses `NotificationCenter` for broad refresh events.

Important notifications:

- `.budgetPlannerDataDidChange`
- `.portfolioDataDidChange`
- `.authSessionDidInvalidate`
- `.authSessionWillInvalidate`
- push-notification route notifications

Example:

- recording an expense posts `.budgetPlannerDataDidChange`
- Home and Reports observe it and reload
- updating portfolio posts `.portfolioDataDidChange`
- Home and Portfolio refresh related metrics

This is pragmatic for sibling tabs that need to refresh without passing callbacks through many layers.

## Navigation

The top-level app uses:

- `TabView` in `HomeScreen`
- `NavigationStack` inside feature roots
- sheets for modal editing
- segmented controls for related sub-views

Main tabs:

- Home
- Portfolio
- Expenses
- Reports
- Settings

Portfolio uses local segmented navigation:

- Holdings
- Allocation
- Watchlist

Reports uses segmented navigation:

- Overview
- Portfolio
- Spending
- Trends

Stock detail uses internal sections/tabs for research, projections, comparison, and related content.

## Main Feature Modules

### Home Dashboard

Important files:

- `Features/Home/HomeScreen.swift`
- `Features/Home/DashboardService.swift`
- `Features/Home/UnifiedActivityFeed.swift`
- `Features/Home/HomeQuickExpenseSheet.swift`
- `Features/Home/AssetSearchViewModel.swift`

The dashboard composes:

- hero wealth/spending card
- dashboard metrics
- stock search
- activity feed
- recent spend
- financial health
- quick expense entry
- insight cards
- focus points

SwiftUI concepts used:

- `NavigationStack`
- `ScrollView`
- `GlassEffectContainer`
- `.searchable`
- `.refreshable`
- `.task`
- `.onReceive`
- `@State` dashboard state
- `@ObservedObject` shared budget store

Concurrency detail: `loadContent()` uses `async let` to load independent data in parallel.

### Portfolio

Important files:

- `Features/Portfolio/PortfolioViewModel.swift`
- `Features/Portfolio/PortfolioScreen.swift`
- `Features/Portfolio/PortfolioAllocationScreen.swift`
- `Models/Local/SDPortfolioStock.swift`

The portfolio module:

- fetches portfolio lists
- fetches holdings
- syncs holdings into SwiftData
- displays current-user scoped cached rows
- supports add/edit/delete positions
- supports target alerts
- shows allocation chart

SwiftUI concepts used:

- `@EnvironmentObject PortfolioViewModel`
- `@Query` for cached holdings
- `NavigationLink`
- `.sheet`
- `.contextMenu`
- `.toolbar`
- `.refreshable`
- Swift Charts `SectorMark`
- `ShareLink`

Important implementation detail: `@Query` returns all cached rows, so the view filters rows with `LocalCacheScope` before computing totals or rendering.

### Watchlist

Important files:

- `Features/Stocks/Watchlist/WatchlistViewModel.swift`
- `Features/Stocks/Watchlist/WatchlistTab.swift`
- `Models/Local/SDWatchlistItem.swift`

The watchlist module mirrors portfolio cache architecture:

- API-backed remote source of truth
- SwiftData local cache
- current-user scoped reads
- list selection
- add/delete watchlist items
- convert watchlist item into portfolio position

SwiftUI concepts used:

- `List`
- `Section`
- `ContentUnavailableView`
- swipe actions
- confirmation dialog
- sheet-driven add/convert flows

### Expenses And Budget Planner

Important files:

- `Features/Expenses/BudgetPlannerModels.swift`
- `Features/Expenses/BudgetPlannerViewModel.swift`
- `Features/Expenses/ExpensesPlannerScreen.swift`
- `Features/Expenses/ExpensesSyncManager.swift`
- `Features/Expenses/ExpensesSwiftDataModels.swift`
- `API/Expenses/ExpensesHTTPClient.swift`
- `API/Expenses/ExpensesEndpoints.swift`

The expenses feature has three layers:

```text
API DTOs -> SwiftData cache -> BudgetPlanner domain models -> SwiftUI screens
```

Important domain types:

- `BudgetPillar`
- `MonthlyBudgetSnapshot`
- `BudgetPlanItem`
- `BudgetActivity`
- `BudgetMonthSummary`
- `BudgetYearSummary`
- `BudgetActivityDraft`
- `BudgetPlanItemDraft`

Important local types:

- `LocalExpense`
- `LocalBudgetSnapshot`
- `LocalBudgetPlanItem`
- `LocalExpenseCategory`
- `LocalRecurringTemplate`
- `OfflineSyncAction`

Important behavior:

- `load(force:)` pulls latest data from API and maps local SwiftData rows into domain state.
- local rows are filtered by current `ownerUserId`.
- a blank user does not get default rent, Netflix, salary, or budget data.
- expense create writes locally first, then queues an offline sync action.
- successful mutations post `.budgetPlannerDataDidChange`.

SwiftUI concepts used in `ExpensesPlannerScreen`:

- `NavigationStack`
- `ScrollView`
- `GlassCard`
- `Menu`
- `.toolbar`
- `.sheet`
- `.confirmationDialog`
- custom form components
- currency parsing
- progress cards
- grouped lists

### Reports

Important files:

- `Features/Reports/ReportsViewModel.swift`
- `Features/Reports/ReportsDashboardPreferences.swift`
- `Features/Expenses/ExpensesComparisonScreen.swift`

Reports are mostly API-backed read models:

- expense overview
- monthly summaries
- yearly summaries
- pillar summaries
- cash flow
- portfolio statistics

`ReportsViewModel` fetches report overview and household partner data. If the report portfolio stats are empty, it can fall back to stock-service portfolio data for the active account.

SwiftUI concepts used:

- segmented `Picker`
- user-customizable dashboard card order
- `@AppStorage`
- Swift Charts
- `ShareableChartButton`
- placeholder cards for empty data

### Stock Research

Important files:

- `Features/Stocks/StockDetailsScreen.swift`
- `Features/Stocks/StockDetailsScreenViewModel.swift`
- `Features/Stocks/StockInsightsViews.swift`
- `Features/MarketData/MarketDataService.swift`
- `Features/MarketData/MarketDataModels.swift`

This module mixes:

- stock profile data
- market snapshots
- historical chart data
- news
- analyst consensus
- financial statements
- DCF valuation
- projections
- comparison views

SwiftUI concepts used:

- nested composed cards
- chart-heavy sections
- placeholder cards for unavailable data
- sheet-based editing
- async loading per section
- share/export formatting

### Settings And Profile

Important files:

- `Features/UserProfile/UserProfileView.swift`
- `Features/UserProfile/UserProfileViewModel.swift`
- `Features/UserProfile/UserProfileService.swift`
- `Features/UserProfile/LanguageSettingsView.swift`
- `Features/UserProfile/HelpSupportView.swift`
- `Features/UserProfile/AboutNorviqaView.swift`

The settings/profile module demonstrates:

- `List`
- `Section`
- `NavigationLink`
- settings-style rows
- sheets
- language and appearance preferences
- LLM connector UI
- account/logout actions
- profile API integration

Settings is a good place to study Apple-style information architecture: grouped sections, clear labels, native navigation, and simple disclosure.

### Onboarding

Important files:

- `Features/Onboarding/OnboardingImportFlow.swift`
- `Features/Onboarding/OnboardingImportViewModel.swift`
- `Features/Onboarding/InitialStockImportScreen.swift`
- `Features/Onboarding/CSVImportViewModel.swift`
- `Features/Onboarding/ManualImportViewModel.swift`

Onboarding is a state-machine style feature. It supports:

- manual entries
- CSV import
- broker/API import flows
- portfolio import completion

Study this for wizard-like SwiftUI flows controlled by enum state.

### Notifications

Important files:

- `Features/Notifications/PushNotificationsAppDelegate.swift`
- `Features/Notifications/PushNotificationsCoordinator.swift`
- `Features/Notifications/PushNotificationsService.swift`
- `Features/Notifications/PushNotificationsExplainerSheet.swift`
- `API/Notifications/PushNotificationsHTTPClient.swift`

This app still uses UIKit interop where iOS requires it:

- `UIApplicationDelegateAdaptor`
- remote notification registration
- notification action handling

SwiftUI owns the app UI, but push registration and notification callbacks require system delegate integration.

## Design System

Important files:

- `AppTheme.swift`
- `Components/GlassCard.swift`
- `Components/MeshGradientBackground.swift`
- `Components/InteractiveLineChart.swift`
- `Components/FormComponents.swift`
- `Components/ToastBanner.swift`
- `Typography/View+Typography.swift`
- `Extensions/GlassEffect+Compat.swift`

### AppTheme

`AppTheme` centralizes:

- tint colors
- secondary tint
- success/warning/danger colors
- background colors
- elevated card backgrounds
- separators
- navigation/tab colors

Use this instead of scattering raw colors through feature views.

### Typography

The typography system gives semantic text roles:

- `.display`
- `.hero`
- `.title`
- `.label`
- `.small`
- `.nano`

Example:

```swift
Text(totalValue.currency)
  .typography(.hero, weight: .bold)
```

This keeps the visual language consistent.

### GlassCard

`GlassCard` is the main surface primitive. It wraps content in:

- padding
- optional background color
- rounded clipping
- Liquid Glass compatibility via `.appGlassEffect`

It appears across Home, Portfolio, Expenses, Reports, Stock Research, and Settings.

### Liquid Glass APIs

The app targets iOS 26.2, so it can use native Liquid Glass directly. The compatibility layer lives in `Extensions/GlassEffect+Compat.swift` so screens can use app-level helpers while still studying the native SwiftUI API.

Core APIs to study:

- `.glassEffect(_:, in:)` applies Liquid Glass to a view. The default is `.regular` glass in a capsule-shaped `DefaultGlassEffectShape`.
- `Glass.regular` is the normal material for cards, chips, top bars, and floating controls.
- `Glass.clear` keeps glass foreground behavior without the regular material. Use it rarely; the app should prefer `.regular` for visible surfaces.
- `Glass.identity` represents no glass effect. It is useful when composing conditional effects without changing layout.
- `.tint(_:)` adds contextual color to glass. Use it for selected chips, prominent metric pills, or status surfaces.
- `.interactive()` makes glass respond to touch and pointer interaction. Use it only on tappable/focusable views.
- `GlassEffectContainer(spacing:)` groups nearby glass shapes so the renderer can combine, blend, and morph them efficiently.
- `.glassEffectID(_:in:)` identifies glass shapes that should morph across animated hierarchy changes.
- `GlassEffectTransition.matchedGeometry` and `.materialize` describe how glass appears, disappears, or morphs during transitions.
- `.buttonStyle(.glass)` is the default Liquid Glass button style for toolbar icons and secondary actions.
- `.buttonStyle(.glassProminent)` is the prominent Liquid Glass button style for primary actions.
- `.buttonStyle(.glass(.regular.tint(...)))` configures a glass button with a custom `Glass` value.

Local wrapper:

```swift
view
  .appGlassEffect(
    .rect(cornerRadius: 16),
    tint: AppTheme.Colors.tint(for: colorScheme),
    interactive: true
  )
```

Use this wrapper for app-branded surfaces that need the same fallback behavior and shape vocabulary. Use native styles directly for standard `Button` controls:

```swift
Button("Save") {
  save()
}
.buttonStyle(.glassProminent)
.tint(AppTheme.Colors.tint(for: colorScheme))
```

Good app usage patterns:

- cards: `GlassCard` or `.appGlassEffect(.rect(cornerRadius: ...))`, not interactive
- chips and custom tab pills: `.glassEffect(.regular.interactive(), in: .capsule)`
- selected chips: `.glassEffect(.regular.tint(AppTheme.Colors.tint(for: colorScheme)).interactive(), in: .capsule)`
- icon toolbar buttons: `.buttonStyle(.glass)`
- primary submit buttons: `.buttonStyle(.glassProminent)`
- grouped chips/buttons: wrap the group in `GlassEffectContainer(spacing:)`
- morphing tab/chip selection: use `@Namespace` plus `.glassEffectID(_:in:)`

Avoid:

- adding `.interactive()` to static cards or labels
- stacking custom material backgrounds under native glass unless a design needs a fallback tint
- replacing system `TabView`, `.searchable`, sheets, menus, or standard navigation chrome when the system already applies native glass behavior
- using `.clear` as the default for cards; it can make surfaces look like old custom blur rather than Liquid Glass

Related SwiftUI 2025 study topics:

- `ToolbarSpacer` creates visual separation between Liquid Glass toolbar items.
- `backgroundExtensionEffect()` extends, mirrors, and blurs edge content into safe-area regions.
- `scrollEdgeEffectStyle(_:for:)` configures scroll edge effects.
- `tabBarMinimizeBehavior(_:)` controls tab bar minimization behavior.
- tabs can use a `search` role so search can replace the tab bar in the right context.

### Empty states

The app uses:

- `ContentUnavailableView`
- `ResearchPlaceholderCard`
- stable min-height frames for dashboard/report cards

For finance dashboards, stable card sizes matter because otherwise empty widgets collapse and make the page feel broken.

## SwiftUI Modifiers To Study

Common layout modifiers:

- `.frame(maxWidth: .infinity)`
- `.frame(minHeight:)`
- `.padding(...)`
- `.background(...)`
- `.clipShape(...)`
- `.safeAreaInset(...)`
- `.ignoresSafeArea()`

Common navigation/presentation modifiers:

- `.navigationTitle(...)`
- `.navigationBarTitleDisplayMode(...)`
- `.toolbar { ... }`
- `.sheet(...)`
- `.confirmationDialog(...)`
- `.navigationDestination(...)`
- `.searchable(...)`

Common lifecycle/data modifiers:

- `.task { ... }`
- `.onAppear { ... }`
- `.onChange(of:)`
- `.onReceive(...)`
- `.refreshable { ... }`

Common animation/feedback modifiers:

- `.animation(..., value:)`
- `.transition(...)`
- `.contentTransition(.numericText())`
- `.sensoryFeedback(...)` through `appSensoryFeedback`

Common accessibility modifiers:

- `.accessibilityLabel(...)`
- `.accessibilityHint(...)`
- `.accessibilityIdentifier(...)`
- `.accessibilityFocused(...)`

## Swift Structures And Patterns Worth Studying

### Protocol-oriented services

Examples:

- `StockServicing`
- `ExpensesServicing`
- `AuthServicing`
- `DashboardServicing`
- `ActivityServicing`

This lets tests inject fake implementations.

### DTO mapping

The app maps between:

- API response DTOs from `StockPlanShared`
- SwiftData local models
- domain models for UI
- view-specific display structs

This is common in production apps. Do not try to use one model type everywhere.

### Draft structs

The app uses draft structs for forms:

- `AddPositionDraft`
- `BudgetActivityDraft`
- `BudgetPlanItemDraft`
- `HomeQuickExpenseDraft`

Drafts separate incomplete form input from validated/persisted domain models.

### Enums for UI modes

Examples:

- `HomeTab`
- `ReportTab`
- `BudgetPillar`
- `ExpenseSplitMode`
- `PortfolioTargetAlertDirection`
- onboarding step enums

Enums make UI state explicit and reduce invalid combinations.

### View models as `@MainActor`

Most view models that mutate UI state are `@MainActor`.

This means:

- `@Published` updates are safe for SwiftUI
- async methods can update state directly
- background work should stay in service/client layers

## Testing Strategy

The app has unit tests for:

- auth session behavior
- auth validation
- HTTP client request construction
- portfolio view-model behavior
- budget planner behavior
- reports view-model behavior
- dashboard logic
- language behavior
- push-notification coordination

Useful test files:

- `financeplanTests/AuthSessionManagerTests.swift`
- `financeplanTests/AuthSessionStoreTests.swift`
- `financeplanTests/PortfolioViewModelTests.swift`
- `financeplanTests/BudgetPlannerViewModelTests.swift`
- `financeplanTests/ReportsViewModelTests.swift`
- `financeplanTests/DashboardLogicTests.swift`
- `financeplanTests/ExpensesHTTPClientTests.swift`

Testing focus:

- business logic
- state transitions
- request construction
- error handling
- persistence behavior

The available shared scheme may not always be configured for test execution, so test-running depends on Xcode scheme setup.

## Files To Study First

Read in this order:

1. `NorviqaApp.swift`
2. `ContentView.swift`
3. `Container+AppFactories.swift`
4. `Constants.swift`
5. `AppTheme.swift`
6. `Models/Local/SharedModelContainer.swift`
7. `Models/Local/LocalCacheScope.swift`
8. `Features/Auth/AuthSessionManager.swift`
9. `Features/Auth/AuthService.swift`
10. `Features/Auth/LoginViewModel.swift`
11. `Features/Auth/LoginScreen.swift`
12. `Features/Home/HomeScreen.swift`
13. `Features/Portfolio/PortfolioViewModel.swift`
14. `Features/Portfolio/PortfolioScreen.swift`
15. `Features/Expenses/BudgetPlannerViewModel.swift`
16. `Features/Expenses/ExpensesSyncManager.swift`
17. `Features/Reports/ReportsViewModel.swift`
18. `Features/Stocks/StockDetailsScreenViewModel.swift`
19. `Components/GlassCard.swift`
20. `Components/FormComponents.swift`
21. `Components/ToastBanner.swift`

That order teaches:

- app shell
- dependency injection
- local persistence
- auth/session
- dashboard composition
- one API-backed local-cache feature
- one heavier domain feature
- reusable UI primitives

## Practical Mental Model

The app works like this:

```text
NorviqaApp
-> ContentView root state machine
-> HomeScreen TabView
-> feature SwiftUI views
-> @StateObject/@ObservedObject view models
-> services from Factory
-> HTTP clients/endpoints
-> backend API
-> DTOs mapped back to domain/local/display models
```

For cached features:

```text
Backend API
-> service
-> sync/local store
-> SwiftData rows with ownerUserId
-> view model domain arrays
-> SwiftUI cards/lists/charts
```

For local-first writes:

```text
SwiftUI form
-> draft struct
-> view model validation
-> local SwiftData insert/update
-> offline sync action
-> API push
-> notification refresh
```

## Final Takeaway

The most important SwiftUI lessons in this client are:

- keep root app flow state-driven
- keep network calls out of view bodies
- let feature view models own loading and mutation
- use services and HTTP clients as separate layers
- scope local persistence by authenticated user
- map DTOs into domain/display models instead of leaking API shape into every view
- use native SwiftUI controls first, then add brand styling through reusable components
- use stable empty states for dashboard UIs
- use `async/await` and `@MainActor` deliberately

The architecture is pragmatic: it uses native SwiftUI, local SwiftData caching, feature-oriented services, and a small design system without trying to make everything abstract.

---

## 📱 Comprehensive Architecture Analysis (Full-Codebase Audit 2026-04-25)

### Repository Layout & Module Map

```
financeplan/
├── NorviqaApp.swift              # @main, theme, global services
├── ContentView.swift             # root router: splash → auth/home/onboarding
├── AppEnvironment.swift          # AppEnvironments.local/dev/production + base URLs
├── SchemeEnvironment.swift       # Xcode scheme pre-action inject (auto-generated)
├── Container+AppFactories.swift  # Factory DI singletons: authService, stockService, …
├── SessionManager.swift          # display username ObservableObject
├── Models/Local/                 # SwiftData models (cache): SDPortfolioStock, SDWatchlistItem, SharedModelContainer
├── Features/
│   ├── Auth/                     # login, signup, MFA, OAuth, AppLock, Privacy/Paywall (pre-login)
│   ├── Home/                     # dashboard cards, quick expense, activity feed, asset search
│   ├── Portfolio/                # holdings list, allocation donut, CRUD sheets, portfolio lists
│   ├── Stocks/                   # detail screen, insights tabs, valuation editor, watchlist
│   ├── Crypto/                   # crypto portfolio + market list
│   ├── Expenses/                 # budget planner, comparison charts, SwiftData sync
│   ├── UserProfile/              # profile edit, settings, billing/paywall, language
│   ├── Onboarding/               # CSV import, manual entry, broker link (IBKR)
│   ├── Reports/                  # statistics, preferences
│   ├── MarketData/               # DCF calculator, market service
│   ├── Earnings/                 # earnings calendar screen
│   ├── Badges/                   # gamification grid
│   ├── Notifications/            # APNS registration, deep-link handling, target alert coordinator
│   ├── Support/                  # feedback sheet
│   ├── Analytics/                # PostHog analytics wrapper
│   └── Launch/                   # SplashScreen
├── API/                          # endpoint descriptors + HTTP clients (AnyAPI)
│   └── <Domain>/
│       ├── <Domain>Endpoints.swift
│       ├── <Domain>HTTPClient.swift
│       └── Container+<Domain>Factories.swift
├── Components/                   # reusable SwiftUI components: GlassCard, ErrorRetryView, …
├── Utilities/                    # parsers, formatters, image/chart helpers
├── Extensions/                   # Shimmer, GlassEffect compatibility
├── Typography/                   # FontScheme Typography, weight/style enums
└── Documentation/               # architecture notes, monetization, source-of-truth

Total Swift files: ~206 (app) + 39 (unit tests) + 5 (UI tests)
```

### Tech Stack Deep Dive

| Layer | Technology | Purpose |
|-------|------------|---------|
| UI framework | SwiftUI (iOS 17+) | Declarative views, NavigationStack, TabView |
| DI container | Factory | `@Injected`, `@InjectedObservable` property wrappers; singleton/composed scopes |
| Networking | AnyAPI (OpenAPI-inspired) + URLSession | type-safe endpoint structs, request modifiers for auth headers |
| Local persistence | SwiftData (Apple's CoreData successor) | cache for expenses & budget; also `UserDefaultsAuthSessionStore` for tokens; Keychain for security code |
| Charts | Swift Charts (iOS Charts framework) | allocation donut, price history, expense comparison |
| Auth | JWT (HS256) | bearer tokens from Vapor backend |
| Push | APNS via PushNotifications framework | device registration + silent notifications |
| Analytics | PostHog + Sentry | product analytics + crash reporting |
| Observability | OSLog | structured logging with categories |
| Concurrency | async/await + @MainActor | network & disk IO; UI updates on main actor |
| State | Combine (selective) + @Published + @StateObject | reactive ViewModel state |

### Architecture Overview

**Pattern**: MV-first hybrid. Views contain minimal logic; ViewModels (`ObservableObject`, `@MainActor`) coordinate services and expose `@Published` state. Services are protocol-oriented (`StockServicing`, `AuthServicing`) with production implementations injected via Factory.

**Directory structure driven by feature folders**. Each feature typically contains:
- `<Feature>Screen.swift` – SwiftUI view
- `<Feature>ViewModel.swift` – state + business logic
- `<Feature>Service.swift` – network/data orchestration
- `<Feature>Models.swift` or `*DTOs.swift` – local view models or request/response types

Cross-cutting concerns (API clients, DI, utilities, components) are lifted to shared folders to avoid duplication.

### Dependency Injection (Factory)

`Container+AppFactories.swift` registers singletons:

```swift
extension Container {
  var appEnvironment: Factory<AppEnvironmentManager> { … }.singleton
  var stockService: Factory<StockService> {
    self { @MainActor in
      StockService(environmentManager: self.appEnvironment(),
                   authSessionManager: self.authSessionManager())
    }.singleton
  }
  // …
}
```

Views read with `@InjectedObservable(\Container.stockService) private var service` or `@Injected(\Container.someService)`.

**Environment switching**: when the user selects a different `AppEnvironment` (local/dev/prod), `Container.shared.reset(scope: .singleton)` tears down all singletons so they re-inject with the new base URL. This is driven from `AppEnvironmentManager.switch(to:)`.

### State & Session Management

**SessionManager** – lightweight ObservableObject holding `username` for app chrome.

**AuthSessionStore** (`UserDefaultsAuthSessionStore`) – persists:
- `authToken` (JWT)
- `refreshToken`
- `authTokenExpiresAt`, `refreshTokenExpiresAt`
- `currentUserID`, `currentUsername`
- `loginIsSignup` flag
- `initialStockImportCompleted` flag per user

**AuthSessionManager** – coordinates:
- token refresh on 401 intercept (called by services)
- logout (revoke refresh + clear store)
- session restoration at launch
- broadcasts `Notification.Name.AuthSessionDidInvalidate` on forced logout

**AppLockManager** – enforces device auth (FaceID/TouchID) when app backgrounds; fallback 6-digit PIN via `SecurityCodeManager` (Keychain).

**BillingManager** – wraps RevenueCat Purchases SDK; handles anonymous aliasing to user ID on login; exposes `isPro` via `@Published` state; `restore Purchases()` for account restore.

### Networking Layer

**Endpoint definition pattern** (AnyAPI):

```swift
struct GetQuoteEndpoint: Endpoint {
  typealias Response = QuoteResponse
  let symbol: String
  var method: HTTPMethod { .get }
  var path: String { "/v1/market/quote/" + symbol.uppercased() }
  var decoder: JSONDecoder { .stockPlanShared }
}
```

**HTTPClient pattern**:

```swift
struct StockHTTPClient {
  let baseURL: URL
  let session: StockURLSessionProtocol
  let authTokenProvider: () -> String?

  func call<E: Endpoint>(_ endpoint: E) async throws -> E.Response where E.Response: Codable { … }
}
```

Token injection via request `modifier` on `URLRequest`:
```swift
if let token = authTokenProvider() {
  request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
}
```

**Error envelope** (backend sends):
```json
{ "data": null, "message": "error string" }
```
`APIErrorDecoding` extracts `message` for user-friendly alerts.

### Shared DTOs (StockPlanShared)

Domain breakdown (16 folders):
- Activity, Auth, Badges, Billing, Broker, Common, Dashboard, Earnings, Expenses, Market (Crypto, PriceChart, Market data), News, Notifications, Portfolio, Statistics, Stocks, UserProfile

All structs conform to `Codable`, `Sendable`, `Equatable` where practical. Date decoding handled via `SharedDateDecoder` (backend uses matching `JSONCoder+Backend`).

**Contract alignment**: `openapi.yaml` on backend is source-of-truth; AnyAPI endpoints should match path/method/semantics. Manual endpoint definitions can drift; periodic validation recommended.

### SwiftData Local Cache

Used primarily for **Expenses** feature to enable offline drafting + background sync.

Models:
- `Expense` (local) – ownerUserId, title, amount, pillar, occurredOn, splitMode, linkedItemId
- `BudgetPlanItem` – ownerUserId, snapshot, title, plannedAmount, pillar
- `BudgetSnapshot` – ownerUserId, month/year, totalBudget, totalSpent

**Important**: Scope all fetches by `ownerUserId == LocalCacheScope.currentOwnerUserId` to isolate multi-account data on shared device. Legacy rows without owner are ignored or migrated on read.

### Charts & Visuals

- Allocation donut uses `Chart` with `SectorMark`; colors from `AppTheme`
- Price history: line chart with gradient fill; dual-axis optional
- Expense comparison: horizontal bar per pillar
- InteractiveLineChart component reused across features
- `ChartExporter` renders chart to PNG for share sheet

### Components

Reusable UI library in `Components/`:
- `GlassCard` – frosted background with border + shadow; `MeshGradientBackground` behind
- `GlowingButton` – brand-styled primary button with gradient border/shadow
- `ErrorRetryView` – error state with retry action
- `EmptyStateView` – generic empty search/list placeholder
- `AppTopBar` – large title + optional environment switcher button (runtime-gated)
- `UserMenuDrawer` – profile/settings sheet
- `ToastBanner` – ephemeral in-app notifications (info/warning/error)
- `ProgressBar` – determinate/indeterminate loading
- `FormComponents` – form fields, buttons

### Typography System

Centralized via `Typography` struct + `FontScheme` protocol. Default scheme `AvenirFontScheme` provides weights/styles. Usage:
```swift
Text("Hello")
  .typography(.title2, weight: .semibold)
```
Extensible to swap system fonts or custom families without touching views.

### Notifications & Deep Links

- APNS category `TARGET_ALERT` deep links to stock detail (`/stock/:symbol`)
- `PushNotificationsCoordinator` handles foreground/background notification responses
- Device token registration on first launch; `PushDevice` model on backend
- `TargetAlertPoller` (backend) runs every N minutes; `TargetAlertEvaluator` determines if price crossed a user-defined target

### Analytics & Telemetry

- **PostHog** – event tracking; initialized in `NorviqaApp` with `POSTHOG_PROJECT_TOKEN`, `POSTHOG_HOST`
- **Sentry** – crash reporting; `SentrySDK.start`
- **Amplitude** – pre-login paywall events (unified SDK), initialized in `AnalyticsService`
- Events use `AnalyticsService.track(event:properties:)` throughout; also companion RevenueCat events

### Storage & Security

- **Keychain**: `SecurityCodeManager` (6-digit fallback PIN) with `kSecAttrAccessibleWhenUnlocked`
- **UserDefaults**: `AuthSessionStore` for tokens/flags; `AppAppearance` for color scheme + language
- **SwiftData**: encrypted at rest by iOS Data Protection; multi-account scoped via `ownerUserId`
- **Network**: all HTTPS (TLS 1.3+); no certificate pinning
- **App Lock**: device auth enforced on background/foreground transition (LocalAuthentication)

### Testing Strategy

- **Unit** (39 files): ViewModels, Services, DTO decoding, utilities
- **UI tests** (5 files): Launch tests, Expenses flow, Stock detail tab navigation, smoke flow
- **Test helpers**: `-ui_test_*` process arguments in `ContentView.init()` for forced auth/reset/import state
- **Mock clients**: protocol-based in-memory service implementations
- **SwiftData test container**: `SharedModelContainer` used by expense tests

### Environment Switching

Three runtime environments configurable from Settings (and AuthFooter in dev):

```swift
enum AppEnvironments {
  static let local       = AppEnvironment(apiBaseUrl: http://localhost:8080, …)
  static let dev         = AppEnvironment(apiBaseUrl: https://www.dev-norviq.online, …)
  static let production  = AppEnvironment(apiBaseUrl: https://www.prod-norviq.online, …)
}
```

**Important**: Visibility of environment-switcher button is controlled by `environment.current != .production` (runtime), *not* `#if DEBUG`. This is the correct approach as confirmed by user preference.

### Recent Feature Work

| Feature | Status | Files of Interest |
|---------|--------|-------------------|
| Pre-login Privacy + Paywall | ✅ | `PrivacyWelcomeScreen.swift`, `PreLoginPaywallScreen.swift`, `AnalyticsService.swift` |
| RevenueCat Billing | ✅ | `BillingManager.swift`, `API/Billing/*`, `Products.storekit` |
| IBKR Broker Sync | ✅ | `BrokerService.swift`, `API/Broker/*`, backend `IBKRBrokerIntegration.swift` |
| Watchlist multi-list | ✅ | `Watchlist/`, backend `WatchlistList` |
| Multi-attachment posts (fandemic) | N/A | distinct feature set for other app |

### Build & CI Notes

- **Scheme**: `Norviqa TestFlight Dev` – test builds; scheme pre-actions currently write unused `SchemeEnvironment.swift`
- **SwiftLint**: `.swiftlint.yml` present; run `swiftlint --fix`
- **PostHog/Sentry**: env vars set in scheme or device
- **UI test arguments**: `-ui_test_skip_splash`, `-ui_test_reset_session`, `-ui_test_auth_token`, `-ui_test_imported_user_id`, etc.

### Code Quality Observations

- Protocol-oriented design → easy mocking in tests
- Factory DI avoids Service Locator misuse; clear singleton boundaries
- ViewModels (`@MainActor`) → UI safety
- Error propagation via `throw` + `LocalizedError` types; `APIErrorDecoding` maps backend envelope
- Date handling via `SharedDateDecoder` consistent between client and server
- SwiftUI declarative; some UIKit interop (OAuth `ASWebAuthenticationSession`, keychain prompts)
- `EnvironmentObject` used sparingly (`SessionManager`, `billingManager`); most injection via Factory

### Suggested Study Path

1. **App lifecycle**: `NorviqaApp` → `ContentView` → session restoration logic
2. **Auth**: `AuthService` → `AuthHTTPClient` → endpoints → backend `AuthController`
3. **Portfolio browse**: `PortfolioViewModel` → `StockService` → `StockHTTPClient` → backend `StockController`/`PortfolioController`
4. **Expenses local cache**: SwiftData models → `ExpensesSyncManager` → sync flow
5. **Market data**: `MarketDataService` → provider pattern (FMP/Finnhub) → HTTP
6. **Billing**: `BillingManager` + RevenueCat SDK → backend `/v1/billing/*`
7. **Notifications**: APNS registration → `TargetAlertPoller` (backend) → deep-link handling
8. **Broker IBKR sync**: `BrokerService` (CSV + OAuth start) → backend → `IBKRBrokerIntegration`

### Related Documentation

- `auth.md`, `auth_arch.md` – authentication layer diagrams
- `monetization.md`, `revenuecat-setup.md` – billing & RevenueCat setup
- `source-of-truth.md` – which features are API-backed vs local cache vs mock
- `persistence-standards.md` – SwiftData conventions and owner-scoping
- `stock-org.md` – how stock domain is organized across files
- `mvp-roadmap.md` – product priorities (deferred features: AI, advanced analytics, etc.)

**Study tip**: Keep `source-of-truth.md` open while navigating code to understand where each feature writes its data. The backend remains authoritative for portfolio, stocks, and expenses; SwiftData is a write-behind cache for offline-first expenses.
