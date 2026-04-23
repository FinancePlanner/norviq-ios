# Norviqa iOS SwiftUI Client Study Guide

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
11. `Features/Home/HomeScreen.swift`
12. `Features/Portfolio/PortfolioViewModel.swift`
13. `Features/Portfolio/PortfolioScreen.swift`
14. `Features/Expenses/BudgetPlannerViewModel.swift`
15. `Features/Expenses/ExpensesSyncManager.swift`
16. `Features/Reports/ReportsViewModel.swift`
17. `Features/Stocks/StockDetailsScreenViewModel.swift`
18. `Components/GlassCard.swift`
19. `Components/FormComponents.swift`
20. `Components/ToastBanner.swift`

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
