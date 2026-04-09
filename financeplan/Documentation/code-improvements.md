# Code Improvements Log (Home + Expenses + Stocks + Onboarding)

This note summarizes the changes implemented, why they were made, and small code samples you can study later.

## 1) Record Spend: fixed silent failure + crash path

### What changed
- Fixed a corrupted line in `BudgetPlannerViewModel.recordExpense(_:)` that was causing parser/runtime instability.
- Fixed expense request encoding to send backend-expected snake_case keys (`occurred_on`, `split_mode`, `user_share_percent`, `linked_plan_item_id`).

### Why
- You were getting `"No such key 'occurred_on'"` from backend.
- UI looked like a no-op because POST payload keys did not match API contract.

### Code sample (client payload fix)
```swift
// financeplan/API/Expenses/ExpensesEndpoints.swift
func asParameters() throws -> Parameters {
    var params: Parameters = [
        "title": payload.title,
        "amount": payload.amount,
        "pillar": payload.pillar.rawValue,
        "occurred_on": payload.occurredOn,
        "split_mode": payload.splitMode.rawValue,
        "user_share_percent": payload.userSharePercent
    ]
    if let linkedPlanItemId = payload.linkedPlanItemId {
        params["linked_plan_item_id"] = linkedPlanItemId
    }
    return params
}
```

### Code sample (record path stabilization)
```swift
// financeplan/Features/Expenses/BudgetPlannerViewModel.swift
func recordExpense(_ draft: BudgetActivityDraft) {
    guard let prepared = prepareExpenseForSave(draft) else { return }
    Task {
        _ = await persistExpense(prepared)
    }
}
```

## 2) Home dashboard: replaced runtime placeholders with live API data

### What changed
- Home metrics now load from:
  - `GET /v1/portfolio/performance`
  - `GET /v1/reports/overview`
- Home chart points are mapped from API payloads (no synthetic runtime generators).
- Month-over-month delta is computed from the latest two data points with zero-guard.
- `Add Entry` now opens quick spend sheet and saves real expense via planner/store flow, then refreshes Home + activity feed.

### Why
- Removed hardcoded numbers/synthetic trends from runtime.
- Ensured Home reflects real persisted data and updates immediately after add-spend.

### Code sample (parallel API load + mapping)
```swift
// financeplan/Features/Home/HomeScreen.swift
async let performanceTask = stockService.fetchPortfolioPerformance()
async let reportsTask = expensesService.getReportsOverview(from: nil, to: nil)
let (performance, reports) = try await (performanceTask, reportsTask)

let portfolioPoints = Self.mapPortfolioPoints(from: performance.points)
let monthlySummaries = reports.monthlySummaries.sorted { $0.monthStart < $1.monthStart }
let spendingPoints = Self.mapSpendingPoints(from: monthlySummaries)

portfolioTotalValue = portfolioPoints.last?.value ?? 0
spendingTotalValue = max(0, monthlySummaries.last?.actual ?? reports.latestMonthSummary?.actual ?? 0)
portfolioDeltaPercent = Self.deltaPercent(from: portfolioPoints.map(\.value))
spendingDeltaPercent = Self.deltaPercent(from: monthlySummaries.map { max(0, $0.actual) })
```

### Code sample (quick add action)
```swift
// financeplan/Features/Home/HomeScreen.swift
private func saveQuickExpense(_ draft: HomeQuickExpenseDraft) async -> String? {
    let didSave = await budgetStore.recordExpenseAndWait(
        BudgetActivityDraft(
            title: draft.title,
            amount: draft.amount,
            pillar: draft.pillar,
            occurredOn: draft.occurredOn,
            linkedPlanItemID: nil,
            splitMode: draft.splitMode,
            userSharePercent: draft.userSharePercent
        )
    )
    guard didSave else {
        return budgetStore.errorMessage ?? "Could not save expense. Please try again."
    }
    await loadHomeMetrics()
    await activityViewModel.loadActivities()
    return nil
}
```

## 3) Stock insights: new backend aggregate endpoint + iOS wiring

### What changed
- Added backend endpoint: `GET /v1/stocks/{symbol}/insights`.
- Endpoint is authenticated and returns aggregate insights:
  - primary profile
  - peer list (watchlist + holdings, excluding primary)
  - deterministic projection scenarios (bear/base/bull)
- iOS now fetches this endpoint in stock details and applies response to compare/forecast state.
- Runtime mock seeding path was removed from the active load flow.

### Why
- Replace mock comparison/projection runtime data with server-generated deterministic data.

### Code sample (backend route)
```swift
// StockPlanBackend/Sources/StockPlanBackend/Stocks/StockController.swift
stocks.get(":symbol", "insights", use: getStockInsights)

func getStockInsights(req: Request) async throws -> StockInsightsResponse {
    let session = try req.auth.require(SessionToken.self)
    let symbol = try requireStringParameter(req, name: "symbol", reason: "Invalid stock symbol")
    return try await req.stocksService.getInsights(
        symbol: symbol,
        userId: session.userId,
        on: req.db
    )
}
```

### Code sample (deterministic scenario config)
```swift
// StockPlanBackend/Sources/StockPlanBackend/Stocks/StockService.swift
private struct ProjectionScenarioConfig {
    let kind: String
    let growthShift: Double
    let peLowShift: Double
    let peHighShift: Double
}

let config: [ProjectionScenarioConfig] = [
    ProjectionScenarioConfig(kind: "bear", growthShift: -0.03, peLowShift: -2, peHighShift: -2),
    ProjectionScenarioConfig(kind: "base", growthShift: 0, peLowShift: 0, peHighShift: 0),
    ProjectionScenarioConfig(kind: "bull", growthShift: 0.03, peLowShift: 2, peHighShift: 2)
]
```

### Code sample (iOS endpoint + view model usage)
```swift
// financeplan/API/Stocks/StockEnpoints.swift
struct GetStockInsightsEndpoint: Endpoint {
    typealias Response = StockInsightsResponse
    let symbol: String
    var method: HTTPMethod { .get }
    var path: String { "/v1/stocks/\(symbol)/insights" }
}

// financeplan/Features/Stocks/StockDetailsScreenViewModel.swift
async let insightsTask = loadInsights(symbol: symbol)
if let insights = await insightsTask {
    applyInsights(insights)
} else {
    self.primaryComparisonProfile = nil
    self.comparisonUniverse = []
    self.selectedPeerSymbols = []
}
```

## 4) Onboarding import: API flow is real (no fake completion path)

### What changed
- `API Import` onboarding step now loads real broker connections and triggers real IBKR sync.
- States are explicit: loading, syncing, error, sync message.
- Wired through `BrokerService` + `BrokerHTTPClient` + broker endpoints.

### Why
- Removed placeholder behavior and sleep-based fake completion.

### Code sample
```swift
// financeplan/Features/Onboarding/OnboardingImportFlow.swift
func load(force: Bool = false) async {
    if isLoading { return }
    if !force, hasLoaded { return }
    isLoading = true
    errorMessage = nil
    defer {
        isLoading = false
        hasLoaded = true
    }
    do {
        connections = try await brokerService.listConnections()
    } catch {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

func syncIBKRNow() async {
    guard !isSyncing else { return }
    isSyncing = true
    errorMessage = nil
    defer { isSyncing = false }
    do {
        let response = try await brokerService.syncIBKR()
        syncMessage = "Sync requested: \(response.status) (\(response.runId.prefix(8)))"
        await load(force: true)
    } catch {
        syncMessage = nil
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
```

## 5) Contract/documentation alignment

### What changed
- Backend OpenAPI updated with `/v1/stocks/{symbol}/insights` and schemas.
- Bruno request added for stock insights endpoint.

### Code sample (OpenAPI path)
```yaml
/v1/stocks/{symbol}/insights:
  get:
    operationId: getStockInsights
```

### Code sample (Bruno request)
```bru
get {
  url: {{baseUrl}}/v1/stocks/:symbol/insights
  body: none
  auth: bearer
}
```

## 6) Verification notes

- `swift build` (backend): passing.
- `xcodebuild ... build` (iOS app): passing.
- Some test targets in this repo still have unrelated pre-existing compile failures (outside this change scope), so full-suite test execution is not clean yet.

## 7) Suggested study order

1. `ExpensesEndpoints.swift` snake_case payload mapping.
2. `BudgetPlannerViewModel.recordExpense` flow and `persistExpense`.
3. `HomeScreen.loadHomeMetrics` parallel API aggregation.
4. `StockController + StockService` insights endpoint implementation.
5. `StockDetailsScreenViewModel` insights application path.
6. `OnboardingImportFlow` broker sync state handling.
