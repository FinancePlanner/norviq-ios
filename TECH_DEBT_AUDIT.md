# Tech Debt Audit — financeplan (iOS)
Generated: 2026-04-26 (updated after quick wins implementation)

## Executive summary
- 3 Critical, 13 High, 25 Medium, 14 Low (55 total findings)
- Largest debt concentration: `Features/Stocks/StockInsightsViews.swift` (3,791 LOC god file), `Features/Expenses/ExpensesPlannerScreen.swift` (2,734 LOC), `Features/Onboarding/OnboardingImportFlow.swift` (1,745 LOC), and duplicated HTTP client boilerplate across 14 API clients.
- Dead code risk: **RESOLVED** — 9 of 11 service stub types deleted; remaining 2 (`MarketDataServiceStub`, `UserProfileServiceStub`) used only in previews.
- Concurrency: **RESOLVED** — `UserProfileViewModel` now `@MainActor`; remaining ViewModels already annotated.
- Test gaps: Zero unit tests for god-file candidates (StockInsights, ExpensesPlanner, OnboardingImportFlow, BadgesView).
- Observability blind spots: 27 catch blocks across HTTP clients with zero structured logging; network/parse failures invisible in production.
- Consistency rot: 14 HTTP clients each reimplement `makeURLRequest`, `errorMessage(from:)`, envelope decoding, and Error enums — high DRY violation.
- Accessibility gaps: 28 icon-only images in OnboardingImportFlow, 4 in BadgesView lack accessibility labels.

Top 5 fix priorities (post–quick wins)
1. F004/F005/NEW1 — Decompose god files (StockInsights, ExpensesPlanner, OnboardingImportFlow) into smaller, testable views/view models.
2. F013U — Consolidate HTTP client boilerplate into shared `BaseHTTPClient` or endpoint utility.
3. F007U — Add structured error logging to all catch blocks in API layer (use PostHog/Sentry).
4. F016 series — Write unit tests for highest-churn, zero-coverage files: StockInsightsViews, ExpensesPlannerScreen, OnboardingImportFlow, BadgesView.
5. NEW3 — Implement retry logic with exponential backoff in HTTP client base class for transient failures.

## Architectural mental model
Single-target iOS SwiftUI app (iOS 26, Swift 6.2+) with feature-based modules under `financeplan/Features/*`. Each feature owns View + ViewModel + Services + DTOs. Dependency injection via Factory library with 15 `Container+*Factories.swift` files modularized across API domain boundaries. Networking uses hand-rolled `HTTPClient` + `Endpoint` pattern across 14 domain-specific clients, each wrapping a shared `URLSession` (injected via protocol). Auth tokens managed by `AuthService`; sessions stored in Keychain. Entry: `NorviqaApp` → `ContentView` → `HomeScreen` tab bar. Environment switching uses `AppEnvironmentManager` with runtime gates (local can switch, prod hidden) — correctly NOT using `#if DEBUG`.

## Findings

| ID | Category | File:Line | Severity | Effort | Description | Recommendation |
|----|----------|-----------|----------|--------|-------------|----------------|
| F001 | Architectural decay | Features/Expenses/ExpensesService.swift:188-212 | **RESOLVED** | M | `ExpensesServiceStub` with 8 `fatalError("Stub not implemented")` methods — unused but present, accidental wiring would crash. | **Deleted** in quick wins — 9 stub types removed entirely. |
| F002 | Architectural decay | Features/Dashboard/DashboardService.swift:31, GoalsService.swift:46, CryptoService.swift:119, NewsService.swift:45, BadgesService.swift:26, PushNotificationsService.swift:94, BrokerService.swift:201, StatisticsService.swift:76 | **RESOLVED** | S | 8 additional unused stub types — dead code. | **Deleted** in quick wins. |
| F003 | Type & contract debt | Features/UserProfile/UserProfileViewModel.swift:16 | **RESOLVED** | S | Missing `@MainActor` on `ObservableObject` with `@Published`. | **Fixed** — `@MainActor` added. |
| F004 | Architectural decay | Features/Stocks/StockInsightsViews.swift:1 (3,791 LOC, 100 members) | Critical | L | God file — single view handles 7 tabs, dozens of nested subviews; impossible to test. | Split into per-tab child views; extract view models; target ~400 LOC/file max. |
| F005 | Architectural decay | Features/Expenses/ExpensesPlannerScreen.swift:1 (2,734 LOC, 75 members) | High | L | Monolithic screen mixing layout, calculations, and business logic. | Extract `ExpensesPlannerViewModel`; break view into smaller, previewable components. |
| NEW1 | Architectural decay | Features/Onboarding/OnboardingImportFlow.swift:1 (1,745 LOC, 34 members) | Critical | L | God-file onboarding flow mixing CSV parsing, API import orchestration, state coordination; no tests. | Decompose: separate CSV parser, import coordinator, progress UI; adopt async/await task groups. |
| NEW2 | Architectural decay | Features/Badges/BadgesView.swift:1 (361 LOC, 10 members) | High | M | Concentrated badge rendering and layout; zero test coverage; becomes risky to modify. | Extract `BadgeCard` and `BadgeGridView` components; add snapshot tests. |
| F006 | Error handling | Features/Home/HomeScreen.swift:538,568; Features/Crypto/CryptoHomeView.swift:826,946 | Medium | S | `try?` on service calls without logging failures. | Replace with `do/catch` logging to Sentry/PostHog; surface user-friendly messages. |
| F007U | Observability gap | API/*/??HTTPClient.swift (27 catch blocks total) | High | M | **Zero structured logging** in any catch block — network failures, decode errors, API error envelopes all silent to observability platform. | Inject logger/Sentry client; log error domain, status code, endpoint in every catch. |
| F008 | Security hygiene | Features/Auth/OAuthWebAuthenticator.swift:140-145 | Medium | S | `presentationAnchor` fallback returns empty `ASPresentationAnchor()` if no key window — OAuth may silently fail. | `fatalError` in DEBUG or propagate error; never return empty anchor. |
| F009 | Performance | Features/Crypto/CryptoHomeView.swift:938 | **RESOLVED** | S | Magic number `800.0` in animation interval. | **Fixed** — extracted to `tickIntervalMs` constant. |
| F010 | Accessibility | Features/Stocks/StockInsightsViews.swift:816,893; Features/Home/UnifiedActivityFeed.swift:174-177; Features/UserProfile/PaywallView.swift:140,154 | **Partially RESOLVED** | S | Several icon-only buttons lacked labels; fixes applied to identified ones. | Remaining: **OnboardingImportFlow** (28 images), **BadgesView** (4 images) need labels; audit other modules for similar gaps. |
| F011 | Dependency & config | Package.resolved | **RESOLVED** | S | No `Package.resolved` committed. | **Fixed** — committed. |
| F012 | Security hygiene | Constants.swift:8-12 (hardcoded URL unwraps) | Low | S | `URL(string: "...")!` — crash if typo; no compile-time validation. | Acceptable for known-good constants; consider static validator at startup in DEBUG. |
| F013U | Consistency rot | API/*/??HTTPClient.swift (14 clients) | High | L | Each client duplicates `makeURLRequest`, `errorMessage(from:)`, `Error` enum, envelope-decoding logic — 14× maintenance burden. | Extract `BaseHTTPClient<E: Endpoint>` with shared implementations; subclasses only customize headers/logging. |
| F014 | Security hygiene | Features/Stocks/StockInsightsViews.swift:816,893 | Medium | S | URL construction with forced fallback `?? URL(string: "https://google.com")!` — could crash if fallback malformed; unvalidated trust boundary. | Validate news URLs before opening; use PKPinnedDomain or allowlist; graceful fallback without force-wrap. |
| F015 | Architectural decay | Features/UserProfile/PaywallView.swift:380,384 | Low | S | Hardcoded external URLs across views. | Centralize `ExternalLinks` struct with validated static `URL` properties. |
| F016 | Test debt | Features/Stocks/StockInsightsViews.swift (0 tests), Features/Expenses/ExpensesPlannerScreen.swift (0 tests) | High | H | No unit tests for two highest-churn files (20+ changes each). | Add ViewModel tests for business logic; UI tests for critical paths. |
| F016U1 | Test debt | Features/Onboarding/OnboardingImportFlow.swift (0 tests) | High | H | Large god file with zero coverage; handles CSV parsing + API orchestration — regression risk extreme. | Unit-test CSV parser, import coordinator, error states separately; integration test full flow. |
| F016U2 | Test debt | Features/Badges/BadgesView.swift (0 tests) | Medium | H | Zero coverage for gamification UI; badge logic subtle (criteria, thresholds). | Snapshot tests for badge states; ViewModel tests for award logic. |
| F017 | Documentation drift | README.md: local setup may not match current env resolution | Low | M | README auth section not verified against `Constants.swift` env resolution. | Sync README with 5-step env resolution (env var > Info.plist > scheme > default). |
| F018 | Consistency rot | API/*/??HTTPClient.swift (13× `errorMessage(from:)` implementations) | **RESOLVED** | M | Each client parses error envelope independently. | **Superseded** by F013U consolidation; becomes sub-problem. |
| F019 | Consistency rot | API/* (13× `makeURLRequest` implementations) | **RESOLVED** | M | Identical URL construction repeated. | **Superseded** by F013U. |
| F020U | Consistency rot | API (HTTPEnvelope / APIEnvelope / BillingHTTPEnvelope) | Low | M | Three envelope type names prevent generic abstractions. | Standardize to `APIEnvelope<DataType>` everywhere; migrate HTTPEnvelope/BillingHTTPEnvelope to typealiases. |
| F021 | Type & contract debt | API/Support/APIErrorDecoding.swift: uses `try?` liberally | Low | S | `try?` hides decoding errors but intentional fallback chain. | Add comment clarifying fallback strategy is by design. |
| F022 | Performance | Features/Crypto/CryptoHomeView.swift:946 | Low | S | `try? await Task.sleep` inside animation loop; cancellation may be ignored. | Check `Task.isCancelled` after sleep; bump priority if needed. |
| F023 | Performance | Features/Home/HomeScreen.swift:1353 | Low | S | Unnecessary `try?` on `Task.sleep` — doesn't throw unless cancelled. | Remove `try?`; handle cancellation in parent if needed. |
| F024 | State hygiene | Features/Home/AssetSearchViewModel.swift:13 | **VERIFIED OK** | S | `searchTask` cancellation — already called in `deinit` and `queryChanged`. | No action needed. |
| F025 | State hygiene | Features/Home/HomeScreen.swift:56 — `pendingStatusUpdates` may grow unbounded | Medium | S | Mutating set in `updateGoalStatus` but never cleared; could leak memory. | Audit mutations; clear after sync or use ephemeral `Set` local to operation. |
| NEW4 | Accessibility | Features/Badges/BadgesView.swift (4 images) | Medium | S | Decorative icons without labels; gamification must be accessible. | Add `.accessibilityLabel()` for each icon type (`"Badge earned"`, `"Badge locked"`, etc.); hide decorative with `.accessibilityHidden(true)`. |
| NEW5 | Consistency rot | Features/*/*Service.swift (15 `authTokenProvider` closure definitions) | Low | M | Every service repeats same closure `authTokenProvider: { Container.shared.authSessionStore().authToken }`. | Replace with `@InjectedObservable(Container.authSessionStore)` injection in service initializers (via Container factories). |
| NEW6 | Observability gap | 27 catch blocks across HTTP clients — no logging | High | M | Silent failures prevent Sentry/PostHog alerts; no visibility into 4xx/5xx or decode errors. | Add `logger.error("API error")` or `SentrySDK.capture` in every catch; include endpoint, status, user ID, correlation ID. |
| NEW7 | Reliability | API/*/??HTTPClient.swift — no retry logic | Medium | L | Single-shot requests fail on transient network (timeout, cellular handoff); no backoff. | Add configurable retry policy (max 3 attempts, 0.5–2s backoff) in base client; idempotency-safe for GET. |

**Resolved in quick wins sweep**
- F001, F002: deleted 9 stub types entirely
- F003: added `@MainActor` to `UserProfileViewModel`
- F009: extracted `tickIntervalMs` constant
- F010: added accessibility labels to StockInsights icons and Paywall checkmarks; hid decorative icons in UnifiedActivityFeed
- F011: committed `Package.resolved`
- F018, F019: subsumed into F013U consolidation plan

## Things that look bad but are actually fine

- **`try? await Task.sleep(...)` in multiple places** — initial concern: suppresses cancellation/programming errors. Verified: used purely as debounce/delay (splash, toast, animation tick, rate limiting). Suppression acceptable because parent task lifecycle handles cancellation; none are on critical paths where failure must surface to user. Consider adding `if Task.isCancelled { return }` after sleep for clarity anyway.

- **`fatalError` in `NorviqaApp.swift:14`** — intentional fast-fail for missing env vars (PostHog/Sentry); correct behavior.

- **`ExpensesServiceStub` returning empty arrays** — some stubs intentionally return empty collections for previews/UI scaffolding; acceptable as long as they don't `fatalError`. Stubs with `fatalError` have been removed.

- **`DispatchQueue.main.async { … }` inside `@MainActor` Task blocks** — redundant but harmless; @MainActor guarantees main thread.

- **Environment resolution order complexity** (`Constants.swift:56-90`) — supports local/dev/prod via multiple mechanisms (env var, Info.plist, scheme, user defaults); required for developer workflow.

- **`URL(string:)!` in Constants** — 3 hardcoded URLs that are compile-time constants; crash immediately if malformed. Acceptable since they're reviewed at build time; could add `guard` with descriptive message in DEBUG for parity.

- **`MarketDataServiceStub` throwing 404** — used in `StockDetailsScreenViewModel` preview to simulate "no market data" state; intentional and acceptable behind preview-only gating.

- **`URLSession.shared` default parameters in service initializers** — technically an implementation detail; all production code constructs services via Container factories that inject mock sessions for tests. No direct instantiation found in production code. The default is technically unused but harmless; could be removed to tighten API.

## Coverage gaps & risk assessment

| Module | Swift files | Test files | Hot files | God-file risk | Immediate action |
|--------|-------------|------------|-----------|---------------|-----------------|
| Stocks | 16 | 4 | StockInsightsViews (0 tests) | **Critical** — 3,791 LOC | Decompose THEN test |
| Expenses | 9 | 3 | ExpensesPlannerScreen (0 tests) | **High** — 2,734 LOC | Decompose THEN test |
| Onboarding | 9 | 3 | OnboardingImportFlow (0 tests) | **Critical** — 1,745 LOC | Decompose THEN test |
| Badges | 3 | 0 | BadgesView (0 tests) | **Medium** — 361 LOC | Test + minor refactor |
| Crypto | 3 | 1 | CryptoHomeView (moderate churn) | Low — already small | Add error-logging tests |
| Home | 6 | 5 | HomeScreen (tested), UnifiedActivityFeed (covered) | Low | Already covered |
| Auth | 23 | 6 | LoginViewModel (tested) | Low | OK |
| UserProfile | 12 | 2 | UserProfileViewModel (tested) | Low | OK |
| Portfolio | 6 | 3 | PortfolioViewModel (tested) | Low | OK |
| MarketData | 3 | 2 | MarketDataService (tested) | Low | OK |

## Open questions for maintainer

1. Are `fatalError` calls in `HomeScreen` guard statements intentional precondition checks? Several guard-else-fatalError patterns exist; confirm acceptable.
2. Is `OAuthPresentationContextProvider` fallback to empty `ASPresentationAnchor()` ever exercised in practice (e.g., app launched from background)? If so, OAuth might fail silently under that edge case — consider `fatalError` in DEBUG or propagate error.
3. Should `Package.resolved` be committed or fully gitignored? Current state: committed to `xcshareddata/swiftpm/`. If all devs use Xcode 16+, committing is correct; verify CI uses same Xcode version.
4. Why does `MarketDataServiceStub` throw 404 instead of returning empty structs? Preview-only contract is understood — confirm no production code accidentally uses the stub.
