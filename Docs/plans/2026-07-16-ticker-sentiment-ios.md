# Ticker Sentiment — iOS Implementation Plan (Plan 2 of 3)

> **For agentic workers:** implement task-by-task, TDD where a unit test is feasible. Steps use `- [ ]`.

**Goal:** Add a Pro-only "Sentiment" tab to the iOS stock detail screen showing notable-account X posts about the symbol, from `GET /v1/insights/tickers/{symbol}/sentiment`.

**Architecture:** A new `API/Insights/` three-file client (endpoint + client + factory) mirroring `API/News/`, local Decodable DTOs, a `.sentiment` case on `StockDetailTab`, a `StockSentimentTab` view, and a lazy load branch in the detail view model.

**Tech Stack:** SwiftUI, AnyAPI/BaseHTTPClient, Factory DI, swift-testing. Repo: `norviq-ios/financeplan` (git root `financeplan/.git`, scheme `financeplan`).

## Global Constraints

- Tab is **Pro-only** (`isProOnly = true`), like analysis/forecast.
- Reads `GET /v1/insights/tickers/{symbol}/sentiment?days=14&limit=20`. Response: `{symbol, windowDays, aggregate{label, score?, postCount}, posts:[{author?, authorHandle?, text, url?, sentimentLabel, sentimentScore?, confidence?, postedAt}]}`.
- DTOs are **local to iOS** (`API/Insights/InsightsDTOs.swift`), Decodable only — do NOT round-trip through norviq-shared.
- Lazy-load on tab select (mirror `.earnings` in `loadSupplementaryDataIfNeeded`), not eagerly.
- Empty `posts` → "No sentiment yet" empty state. Non-Pro → existing Pro-gate teaser.
- Follow the `API/News/` file/naming conventions exactly.

## File map
- Create `API/Insights/InsightsDTOs.swift`, `API/Insights/InsightsEndpoints.swift`, `API/Insights/InsightsHTTPClient.swift`, `API/Insights/Container+InsightsFactories.swift`
- Create `Features/Stocks/Detail/StockSentimentTab.swift`
- Modify `Features/Stocks/StockInsightsModels.swift` (enum), `Features/Stocks/StockDetailsScreen.swift:216,279` (switch), `Features/Stocks/StockDetailsScreenViewModel.swift` (state + load branch), `financeplan/Localizable.xcstrings`
- Test `financeplanTests/…` (view-model load test with a stub client)

---

### Task 1: Insights API client (DTOs + endpoint + client + factory)

**Files:** create the four `API/Insights/*` files.

**Interfaces produced:**
- `TickerSentimentResponse` (Decodable) + nested `TickerSentimentAggregate`, `TickerSentimentPost`.
- `InsightsHTTPClient.getTickerSentiment(symbol:days:limit:) async throws -> TickerSentimentResponse`.
- `Container.insightsHTTPClient` factory.

- [ ] **Step 1: DTOs** — `API/Insights/InsightsDTOs.swift`:
```swift
import Foundation

struct TickerSentimentResponse: Decodable, Sendable, Equatable {
    let symbol: String
    let windowDays: Int
    let aggregate: TickerSentimentAggregate
    let posts: [TickerSentimentPost]
}

struct TickerSentimentAggregate: Decodable, Sendable, Equatable {
    let label: String
    let score: Double?
    let postCount: Int
}

struct TickerSentimentPost: Decodable, Sendable, Equatable, Identifiable {
    let author: String?
    let authorHandle: String?
    let text: String
    let url: String?
    let sentimentLabel: String
    let sentimentScore: Double?
    let confidence: Double?
    let postedAt: String
    var id: String { (url ?? "") + postedAt + text }
}
```

- [ ] **Step 2: Endpoint** — `API/Insights/InsightsEndpoints.swift` (mirror `GetNewsEndpoint`):
```swift
import AnyAPI
import Foundation

struct GetTickerSentimentEndpoint: Endpoint {
    typealias Response = TickerSentimentResponse
    let symbol: String
    let days: Int?
    let limit: Int?

    var method: HTTPMethod { .get }
    var path: String { "/v1/insights/tickers/\(symbol)/sentiment" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        if let days { params["days"] = String(days) }
        if let limit { params["limit"] = String(limit) }
        return params
    }
}
```

- [ ] **Step 3: Client** — `API/Insights/InsightsHTTPClient.swift` (copy `NewsHTTPClient`'s `Error` enum + init verbatim, category "InsightsHTTPClient"), with:
```swift
func getTickerSentiment(symbol: String, days: Int? = 14, limit: Int? = 20) async throws -> TickerSentimentResponse {
    try await client.call(GetTickerSentimentEndpoint(symbol: symbol, days: days, limit: limit), errorType: Error.self)
}
```

- [ ] **Step 4: Factory** — `API/Insights/Container+InsightsFactories.swift` (mirror `Container+NewsFactories.swift`): register `var insightsHTTPClient: Factory<InsightsHTTPClient>` with `baseURL: env.current.apiBaseUrl` + `authTokenProvider`. Read the News factory first and match its exact registration style/scope.

- [ ] **Step 5: Build**

Run: `cd /Users/fernando_idwell/Projects/StockProject/norviq-ios/financeplan && xcodebuild -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit** — `git add financeplan/API/Insights && git commit -m "feat(insights): iOS ticker sentiment API client"`

---

### Task 2: `.sentiment` tab enum case

**Files:** modify `Features/Stocks/StockInsightsModels.swift`.

- [ ] **Step 1:** add `case sentiment` after `case news`; add `case .sentiment: "Sentiment"` to the `title` switch; add `.sentiment` to the Pro-only branch of `isProOnly` (`case .builder, .forecast, .statements, .analysis, .compare, .earnings, .sentiment: return true`).
- [ ] **Step 2: Build** (as Task 1 Step 5). Expected: BUILD SUCCEEDED (the `switch selectedTab` in StockDetailsScreen will now be non-exhaustive — that's Task 3; if the build fails only on that exhaustiveness, proceed to Task 3 then build).
- [ ] **Step 3: Commit** — `git commit -am "feat(insights): add .sentiment stock detail tab case"`

---

### Task 3: Sentiment tab view + screen wiring

**Files:** create `Features/Stocks/Detail/StockSentimentTab.swift`; modify `Features/Stocks/StockDetailsScreen.swift` (switch at ~216, add `case .sentiment:`), `Features/Stocks/StockDetailsScreenViewModel.swift` (state + load branch).

**Interfaces consumed:** `InsightsHTTPClient.getTickerSentiment`, `Container.insightsHTTPClient`, `TickerSentimentResponse`.

- [ ] **Step 1: View model state + load** — in `StockDetailsScreenViewModel.swift`: add `@Published var tickerSentiment: TickerSentimentResponse?` and `@Published var isLoadingSentiment = false`; inject `@Injected(\.insightsHTTPClient)`; add a `.sentiment` case in `loadSupplementaryDataIfNeeded(for:)` guarded by `loadedTabs`/`loadingTabs` (mirror `.earnings`) that calls `getTickerSentiment(symbol:)` and stores the result; swallow errors into an empty state (log, leave `tickerSentiment` nil). Read the `.earnings` branch first and match its guard pattern exactly.

- [ ] **Step 2: View** — `StockSentimentTab.swift`: given `TickerSentimentResponse?` + loading flag, render:
  - loading → progress spinner;
  - nil / empty `posts` → empty state ("No sentiment yet" — mirror `StockNewsTab`'s empty state);
  - else → an aggregate header (sentiment badge from `aggregate.label`, `postCount`, optional score) over a `LazyVStack` of post cards (author + `@handle`, verbatim `text`, sentiment badge, tap opens `url` via `openURL`). Reuse `Features/Crypto/Cards/MarketSentimentCard.swift` styling if it fits.

- [ ] **Step 3: Screen switch** — add `case .sentiment: StockSentimentTab(...)` in the `switch selectedTab` at StockDetailsScreen.swift:216 (Pro-gate handled by the existing tab-bar/gate the same way `.analysis` etc. are).

- [ ] **Step 4: Build.** Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit** — `git commit -am "feat(insights): stock sentiment tab view + wiring"`

---

### Task 4: View-model unit test

**Files:** test file under `financeplanTests/` (mirror an existing stock-detail VM test).

- [ ] **Step 1:** write a test that injects a stub `InsightsHTTPClient` (or protocol-abstract it minimally if the client isn't already injectable via Factory in tests — check how existing VM tests stub News/earnings clients) returning a fixture `TickerSentimentResponse` with 2 posts; call `loadSupplementaryDataIfNeeded(for: .sentiment)`; assert `tickerSentiment?.posts.count == 2` and the aggregate label surfaces. If the client isn't cleanly stubbable, assert the empty-state path (no crash, nil result) instead and note it.
- [ ] **Step 2: Run** `xcodebuild -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:financeplanTests/<YourTest> 2>&1 | tail -8`. Expected: test passes.
- [ ] **Step 3: Commit** — `git commit -am "test(insights): sentiment tab view-model load"`

---

### Task 5: Localizable strings

**Files:** `financeplan/Localizable.xcstrings`.

- [ ] **Step 1:** add keys for user-facing copy ("Sentiment", "No sentiment yet", aggregate labels if surfaced). Match the existing xcstrings format; add English (+ pt-PT if that locale is populated).
- [ ] **Step 2: Build.** Expected: BUILD SUCCEEDED.
- [ ] **Step 3: Commit** — `git commit -am "chore(insights): localizable strings for sentiment tab"`

## Verification
- App builds for the iPhone simulator.
- Stock detail shows a Pro-gated Sentiment tab; for a tracked symbol it lists real posts, for an untracked one it shows the empty state.

## Notes
- Backend contract is live on `main` (Plan 1, PR #100): `/v1/insights/tickers/{symbol}/sentiment`.
- If `xcodebuild` can't run in the execution environment (signing/simulator), compile-verify the Swift as far as possible and flag that a device/simulator build is still needed.
