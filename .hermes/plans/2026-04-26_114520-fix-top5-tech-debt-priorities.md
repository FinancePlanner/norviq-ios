# Plan: Fix Top 5 Tech Debt Priorities
**Generated:** 2026-04-26T11:45:20.251787  
**Workspace:** /Users/fernando_idwell/Projects/StockProject/StockPlanIOSApp/financeplan  
**Project:** financeplan (iOS SwiftUI)  
**Scope:** Post–quick-wins audit remediation  

---

## Goal
Implement the top 5 fixes identified in the tech debt audit (`TECH_DEBT_AUDIT.md`):

1. **Decompose god files** — F004/F005/NEW1 (StockInsights, ExpensesPlanner, OnboardingImportFlow)
2. **Consolidate HTTP client boilerplate** — F013U (14 clients)
3. **Add structured error logging** — F007U/NEW6 (27 catch blocks)
4. **Write tests for zero-coverage files** — F016 series (StockInsights, ExpensesPlanner, OnboardingImportFlow, BadgesView)
5. **Add retry logic** — NEW3 (transient network resilience)

---

## Current context & assumptions

### Completed quick wins (verified)
- 9 unused stub types deleted (no `fatalError("Stub")` remain)
- `UserProfileViewModel` annotated `@MainActor` (all VMs confirmed isolated)
- Accessibility labels added to StockInsights (2 images) and Paywall (4 checkmark/xmark icons)
- UnifiedActivityFeed decorative icons hidden (`.accessibilityHidden(true)`)
- Magic number `800.0` extracted to `tickIntervalMs` in CryptoHomeView
- SPM `Package.resolved` committed and git-tracked
- AssetSearchViewModel cancellation logic verified correct

### Architecture snapshot
- 14 HTTP clients: `AuthHTTPClient`, `BrokerHTTPClient`, `CryptoHTTPClient`, `DashboardHTTPClient`, `ExpensesHTTPClient`, `GoalsHTTPClient`, `MarketDataHTTPClient`, `NewsHTTPClient`, `StockHTTPClient`, `UserProfileHTTPClient`, `BadgesHTTPClient`, `BillingHTTPClient`, `ActivityHTTPClient`, `PushNotificationsHTTPClient`
- DI via Factory; all services injected through `Container+*Factories.swift`
- All ViewModels already `@MainActor`
- Zero `try!` / `as!` outside Constants/NorviqaApp (acceptable)
- Observability platform present but not invoked (PostHog/Sentry initialized)

### God-file landscape (current)
| File | LOC | Members | Test coverage |
|------|-----|---------|---------------|
| StockInsightsViews.swift | 3791 | ~100 | 0 |
| ExpensesPlannerScreen.swift | 2734 | ~75 | 0 |
| OnboardingImportFlow.swift | 1745 | ~34 | 0 |
| BadgesView.swift | 361 | ~10 | 0 |

### HTTP client duplication (current)
- `makeURLRequest<E: Endpoint>`: 14 identical implementations
- `errorMessage(from: Data)`: 13 implementations (Billing uses envelope-specific variant)
- `Error` enums: 13 definitions (slightly different cases)
- Envelope types: `HTTPEnvelope` (Goals, Expenses), `APIEnvelope` (Auth, Crypto, Broker, …), `BillingHTTPEnvelope` (Billing)
- Catch blocks: 27 total — zero call `logger.error()` or Sentry

---

## Proposed approach

### Phase 1 — HTTP client consolidation (F013U, NEW3, NEW6)  [Effort: 2–3 days]
**Why first?** Reduces duplication, establishes base for retry+logging in one place. Does not touch god files.

1. Create `BaseHTTPClient` abstract class in `API/Base/BaseHTTPClient.swift`
   - Generic `call<E: Endpoint>(_ endpoint: E) async throws -> E.Response`
   - Shared `makeURLRequest`, `validate(response:)`, `decode<E: Endpoint>(_ data: Data)` using protocol-provided `decoder`
   - Default `errorMessage(from:)` implementation reading from `APIEnvelope` (standardize envelope first)
   - `@Sendable` closures; respect `@MainActor` boundaries
2. Introduce `HTTPClientError` unified error type (covers network, status, decoding, API envelope errors)
3. Migrate one reference client (e.g., `AuthHTTPClient`) to subclass `BaseHTTPClient`
   - Verify compile + tests (`AuthHTTPClientTests`, `AuthValidationTests`)
4. Envelope normalization
   - Rename `HTTPEnvelope` → `APIEnvelope` via typealias or rename across Goals/Expenses
   - Merge `BillingHTTPEnvelope` into `APIEnvelope` with generic `DataType` payload
5. Add retry policy to `BaseHTTPClient`
   - Configurable `maxRetries: Int` (default 3), `initialBackoff: Duration` (0.5 s)
   - Exponential backoff: `pow(2, attempt) * initialBackoff`, jitter optional
   - Idempotency-safe: only retry GET/HEAD (configurable per-endpoint via `Endpoint.retryable`)
6. Add structured error logging to `BaseHTTPClient.catch` path
   - Inject `Logger` or `Sentry` via protocol (e.g., `ErrorReporting`)
   - Log: endpoint path, HTTP status, error domain, user ID (if available), correlation ID
7. Migrate remaining 13 clients to `BaseHTTPClient` one-by-one, running corresponding test suites after each

**Deliverables**
- `API/Base/BaseHTTPClient.swift` + `HTTPClientError.swift`
- Envelope type standardization (`APIEnvelope` everywhere)
- All 14 clients subclass base, inherit retry+logging
- Test coverage: ensure existing client tests still pass; add new tests for retry & logging

**Risks**
- Subclassing with generics can be tricky; prefer composition if Factory constraints tighter
- Envelope migration may require coordinated changes across DTOs; use temporary typealiases to ease transition

---

### Phase 2 — God-file decomposition (F004/F005/NEW1)  [Effort: 1–2 weeks]
**Why second?** Largest architectural drag; once HTTP base is stable, we can refactor without ripple.

#### 2.1 StockInsightsViews (3,791 LOC → ~10 files)
- Extract per-tab views: `StockNewsView`, `StockHistoricalsView`, `StockStatsView`, `StockAnalystView`, `StockHoldersView`, `StockESGView`, `StockFinancialsView`
- Create `StockInsightsViewModel` to hold tab state and fetch logic
- Move cell components to `Components/StockInsights/`: `NewsRow`, `ChartCard`, `MetricGrid`, `AnalystBar`
- Extract `FeaturedNewsHero` and `NewsFeedRow` into their own files
- Target: each view <400 LOC, ViewModel ~200 LOC

#### 2.2 ExpensesPlannerScreen (2,734 LOC → ~8 files)
- Extract `ExpensesPlannerViewModel` with all calculation logic (budget allocation, pillar totals, projections)
- Break view into: `BudgetPillarCard`, `ExpenseEntryRow`, `BudgetChart`, `BudgetSummary`
- Move validation/formatting helpers to `Utilities/BudgetFormatter.swift`
- Target: ViewModel ~300 LOC, views ~250–400 LOC each

#### 2.3 OnboardingImportFlow (1,745 LOC → ~6 files)
- Extract CSV parsing: `CSVParser.swift` (pure function)
- New coordinator: `ImportCoordinator` (orchestrates CSV → API calls, progress)
- Split UI: `CSVPreviewStep`, `ColumnMappingStep`, `ImportProgressStep`, `ErrorRecoveryStep`
- Extract `BrokerAPIImportViewModel` (already inner class) to top-level
- Extract `ExpenseBudgetSetupViewModel` (already inner class) to top-level
- Adopt Swift concurrency task groups for parallel import batches
- Target: each step view <300 LOC; coordinator ~200 LOC; parser ~100 LOC

**General decomposition rules**
- New views take `let` inputs only; mutable state lives in ViewModel
- Use `@Observable` (Swift 6) or `@State` only in views, not in ViewModels
- Prefer `NavigationStack` path-driven navigation over sheet/presentations for clarity
- Add `#if DEBUG` preview providers per new view

**Validation**
- Each extracted view must compile in isolation with mock data
- Snapshot tests for each new component (XCTest + iOSSnapshotTestCase or ViewInspector)
- No regression in existing flow (smoke test on device/simulator)

---

### Phase 3 — Test coverage (F016 series)  [Effort: 2–3 days per god file]
**Couple with Phase 2** — tests written alongside decomposition.

For each decomposed file:
- **ViewModel unit tests**
  - Business logic only (no SwiftUI)
  - Test state transitions, calculations, async flows
  - Targets: `financesTests/` with `XCTest`
- **UI snapshot tests**
  - Use `ViewInspector` or `iOSSnapshotTestCase` if already in project
  - Cover light/dark schemes, dynamic type sizes
- **Integration test** (for OnboardingImportFlow)
  - CSV sample → import success path
  - Error paths (malformed CSV, network timeout, partial success)

Pre-existing god files that remain monolithic (StockInsights, ExpensesPlanner):
- Add ViewModel tests immediately (extract logic to ViewModel first if needed inline)
- Add UI tests targeting critical user journeys (e.g., "Add stock to watchlist", "Set budget pillar")

**Deliverables**
- 10+ new test files across god-file modules
- CI integration ensure tests run on PRs

---

### Phase 4 — Error logging & observability (F007U, NEW6)  [Effort: 1 day]
After HTTP base exists:
- Create `ErrorReporting` protocol (Covid-style logger/Sentry client)
- Inject into `BaseHTTPClient` initializer
- In each `catch` branch, call `report(error:endpoint:status:userID:)`
  - Include `endpoint.path`, `HTTPURLResponse.statusCode`, `error.localizedDescription`, `Container.shared.authSessionStore().authToken` hash (last 4 chars only)
  - Add `Task.localCurrent`/`UUID` correlation ID if available
- Extend same pattern to service layer catch blocks where `try?` currently used (HomeScreen, CryptoHomeView)
  - Replace `try?` with `do/catch` that logs and sets user-friendly error state

**Validation**
- Trigger a 404 in dev; verify Sentry/PostHog event received
- Check logs include endpoint and user identifier (hashed)

---

### Phase 5 — Retry logic (NEW3)  [Embedded in Phase 1]
Already included in `BaseHTTPClient` design:
- `Endpoint` protocol add `var isRetryable: Bool { get }` (default false; GET/HEAD override true)
- Base client performs up to `maxRetries` attempts with exponential backoff
- Stop early on non-retryable errors (`4xx` client errors other than 429; invalid request)
- Respect `Task.isCancelled` between attempts

---

## Files likely to change

### New files
- `API/Base/BaseHTTPClient.swift`
- `API/Base/HTTPClientError.swift`
- `API/Base/Endpoint+Retryable.swift` (optional protocol extension)
- `Features/Stocks/NewsRow.swift`, `StockChartView.swift`, `StockMetricsGrid.swift`, … (StockInsights splits)
- `Features/Expenses/BudgetPillarCard.swift`, `ExpenseEntryRow.swift`, `BudgetChart.swift`, `BudgetSummary.swift`
- `Features/Onboarding/CSVParser.swift`, `ImportCoordinator.swift`, `CSVPreviewStep.swift`, `ColumnMappingStep.swift`, `ImportProgressStep.swift`, `ErrorRecoveryStep.swift`
- `Features/Badges/BadgeCard.swift`, `BadgeGridView.swift`
- Tests: `financeplanTests/Stocks/*ViewTests.swift`, `Expenses/*ViewModelTests.swift`, `Onboarding/*Tests.swift`, `Badges/*Tests.swift`

### Modified files
- All 14 `*HTTPClient.swift` files (subclass base)
- Envelope definitions in `AuthHTTPClient`, `ExpensesHTTPClient`, `GoalsHTTPClient`, `MarketDataHTTPClient`, `BillingHTTPClient` (rename to `APIEnvelope`)
- `HomeScreen.swift` and `CryptoHomeView.swift` (replace `try?` with `do/catch` logging)
- `Features/Home/AssetSearchViewModel.swift` (already good — no change)
- `Features/Onboarding/OnboardingImportFlow.swift` (extract inner classes; reduce to coordinator glue)
- `Features/Badges/BadgesView.swift` (extract components)
- `Features/Stocks/StockInsightsViews.swift` (extract components; leave thin layout shell)
- `Features/Expenses/ExpensesPlannerScreen.swift` (extract components; ViewModel logic moved out)

### Tests to add
- `BaseHTTPClientTests`: verify retry/backoff, error logging, envelope decoding
- `AuthHTTPClientTests`: ensure subclass behavior intact
- `StockInsightsViewModelTests`: tab selection, data loading, error states
- `ExpensesPlannerViewModelTests`: budget calculations, pillar percentages
- `CSVParserTests`: valid CSV, malformed rows, edge delimiters
- `ImportCoordinatorTests`: happy path + partial failure handling
- `BadgeViewModelTests`: award eligibility logic
- UI snapshot tests via `ViewInspector` for 20+ new views

---

## Validation & done checklist

- [ ] All 14 HTTP clients compile and existing tests pass
- [ ] `BaseHTTPClient` retry works (manual network stubbing test)
- [ ] Sentry/PostHog receives test error from each client in dev
- [ ] God-file LOC reduced: each file <800 LOC, new components <400 LOC
- [ ] Zero compile warnings in modified targets
- [ ] All new ViewModel unit tests pass (≥80% coverage on new logic)
- [ ] UI snapshot tests pass on iPhone 15 (light/dark)
- [ ] Accessibility: VoiceOver navigates OnboardingImportFlow + BadgesView with all labels
- [ ] No regression on critical flows:
  - Stock Insights tabs load data
  - Expenses budget planner calculations correct
  - Onboarding import completes (CSV → broker sync)
  - Badges award display updates on achievement
- [ ] CI green (if `.github/workflows/ci.yml` exists)
- [ ] `TECH_DEBT_AUDIT.md` updated to reflect progress (severity/effort adjustments)

---

## Risks, tradeoffs & open questions

### Risks
- **God-file extraction risk:** massive refactor risk across 4 large files; could introduce regressions if not heavily tested. Mitigation: write tests BEFORE extraction where possible (characterization tests), use feature flags to hide incomplete work.
- **HTTP client consolidation risk:** generic `BaseHTTPClient` may conflict with existing Factory patterns (which rely on concrete types). Plan: keep each concrete client but subclass base, preserving Factory bindings.
- **Envelope normalization risk:** renaming `HTTPEnvelope` → `APIEnvelope` is pervasive (Goals, Expenses, maybe others). Plan: introduce typealias `APIEnvelope = HTTPEnvelope` first, migrate consumers, then remove old name.

### Tradeoffs
- **Retry backoff:** aggressive retry could amplify thundering herd on flaky networks. Use jitter (random 0–0.5 s) or limit concurrent retries.
- **Test writing vs refactor speed:** thorough tests slow down delivery but critical for god files. Balance: snapshot coverage fast; ViewModel unit tests deeper.
- **Accessibility labels:** adding 32 labels in OnboardingImportFlow is tedious but mechanical; no tradeoff.

### Open questions (maintainer)
1. Does backend already support `APIEnvelope<T>` unification, or do we need to coordinate schema changes? (Audit says Goals/Expenses use `HTTPEnvelope` — confirm server sends same structure.)
2. Are there custom `Endpoint` subclasses that override `decode` in non-standard ways? If yes, base class must honor overrides.
3. Should retry policy be configurable per-environment (dev off, prod on)? ConsiderFeature flag `EnableAPIRetry` gated by `AppEnvironment`.
4. Should `BaseHTTPClient` also absorb authentication header injection (currently each client sets MFA header inline)? If yes, consolidate in base.

---

## Order of operations (recommended)

**Week 1:** HTTP consolidation (Phase 1)
- Day 1–2: Base + envelope normalization + Auth migration
- Day 3–4: Migrate remaining clients; run full test suite nightly
- Day 5: Add retry + logging; smoke test on device

**Week 2:** God-file decomposition (Phase 2)
- Day 1: StockInsights decomposition + ViewModel extraction
- Day 2–3: StockInsights snapshot tests + validation
- Day 4: ExpensesPlanner decomposition
- Day 5: ExpensesPlanner tests

**Week 3:** Onboarding + Badges decomposition + tests
- Day 1–2: OnboardingImportFlow split (CSV parser, coordinator, steps)
- Day 3: BadgesView split
- Day 4–5: Tests for both; accessibility labels added to Onboarding images

**Ongoing:** Error logging (Phase 4) as base client matures; integrate into services after HTTP layer stable.

---

**Plan file saved to:** `/Users/fernando_idwell/Projects/StockProject/StockPlanIOSApp/financeplan/.hermes/plans/2026-04-26_114520-fix-top5-tech-debt-priorities.md`
