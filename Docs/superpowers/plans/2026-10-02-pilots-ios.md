# Pilot Follows (iOS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let iOS users browse curated pilots (members of Congress and 13F funds), follow one into a new simulated portfolio (Pro) or a watchlist feed (Free: one follow), and watch the follow's simulated trades, value chart, pause/resume and stop, from a "Follow a pilot" row in the portfolio workspace and a "Following <pilot>" banner on followed portfolios.

**Architecture:** A Boards-style three-file API client (`API/Pilots/`) over the shared `StockPlanShared` 5.17.0 DTOs, with an error type that keeps the 400/403/404/409/422 statuses the UI must tell apart. A `PilotsServicing` protocol feeds `@MainActor @Observable` models; one Factory singleton, `PilotsStore`, owns "is the feature on" plus the viewer's follows so the workspace row, the portfolio banner and the pilot screens agree. All copy and rules live in two pure, tested files (`PilotFollowRules`, `PilotFormatting`).

**Tech Stack:** SwiftUI (iOS 18, Swift 6, default `MainActor` isolation), Observation, Factory (`@InjectedObservable`), AnyAPI + `BaseHTTPClient`, Swift Charts, XCTest, StockPlanShared 5.17.0. Repo/worktree: `/Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots` (branch `feat/pilots-ios`), project `financeplan.xcodeproj`, scheme `financeplan`.

**Spec:** `/Users/fernandocorreiachill/Work/production/apps/norviq/norviq-backend-gates/docs/superpowers/specs/2026-10-01-pilot-follow-design.md` (Phase 3 is this plan). API contract: `/Users/fernandocorreiachill/Work/production/apps/norviq/norviq-backend-gates/Sources/StockPlanBackend/openapi.yaml` (tag `Pilots`). DTOs: `/Users/fernandocorreiachill/Work/production/apps/norviq/norviq-shared/Sources/StockPlanShared/Pilots/PilotDTOs.swift`.

## Global Constraints

- StockPlanShared is pinned **exactVersion 5.17.0** (tag `v5.17.0`, revision `8d9cf53edb1605b8395cc8e52bc4818938f9df89`) in the single `XCRemoteSwiftPackageReference "norviq-shared"` of `financeplan.xcodeproj/project.pbxproj` and in `financeplan.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. (The spec mentions a second `financeplan-brand` target and tag 5.15.0; this repo has one package reference shared by every target, and the tag that carries the DTOs is 5.17.0.)
- Use the shared DTOs as-is: `PilotSummary`, `PilotDetail`, `PilotWeight`, `PilotDisclosureItem`, `PilotFollowCreateRequest`, `PilotFollowUpdateRequest`, `PilotFollowResponse`, `PilotFollowEventResponse`, `PilotFollowSnapshotResponse`, `PilotKind`, `PilotFollowTargetKind`, `PilotFollowStatus`. No local copies.
- Routes used: `GET /v1/pilots`, `GET /v1/pilots/{slug}`, `GET /v1/pilot-follows`, `POST /v1/pilot-follows` (sends `Idempotency-Key`), `PATCH /v1/pilot-follows/{followId}` (body `{status}`), `DELETE /v1/pilot-follows/{followId}` (204), `GET /v1/pilot-follows/{followId}/events`, `GET /v1/pilot-follows/{followId}/snapshots`.
- Every pilots route returns **404 when `PILOTS_ENABLED` is off**. A 404 from `GET /v1/pilots` or `GET /v1/pilot-follows` hides the "Follow a pilot" row and every "Following" banner, with no alert.
- `POST /v1/pilot-follows` errors are handled distinctly: **400** starting capital, **403** upgrade required (or token scope), **404** pilot/list missing or feature off, **409** pilot has no trades yet (or duplicate follow), **422** target not empty.
- Free: **1 follow, watchlist only**; choosing a portfolio target shows the paywall. Pro: **up to 10 follows**, portfolio or watchlist.
- Portfolio follows always create a **new** hypothetical portfolio (`portfolioListId: nil`). Starting capital must be **> 0 and ≤ 10,000,000**, in **USD** (the backend creates the portfolio with base currency USD). Watchlist follows use a new watchlist (`watchlistListId: nil`) or an existing one the server checks is empty.
- A pilot with `holdingsCount == 0` shows **"No trades seen yet"** and cannot be followed.
- The follow sheet's disclaimer must say: simulated, **no real money**, disclosures are **lagged (up to 45 days for Congress, up to 135 days for 13F funds)**, trades are **priced when Norviq sees the disclosure**.
- Manual edits to a followed portfolio return **409 "This portfolio is managed by a pilot follow. Stop following to edit it."**; existing holdings UI shows that reason verbatim.
- Naming: use "pilot" and "follow" only. The competitor brand named in the spec's Naming rule must not appear in code, copy, identifiers, tests, file names or commit messages. Check: `grep -rniE 'auto.?pilot' financeplan financeplanTests docs` prints nothing.
- Patterns (match `Features/Boards/`): `@MainActor @Observable final class` models owned with `@State`; services behind a protocol, injected through an init default of `Container.shared.<service>()`; shared state is a Factory `.singleton` read with `@InjectedObservable(\Container.x)`; small private subviews rather than computed `some View` helpers; `.task` for loads; list screens use `VigilPageHeader` + `.vigilListChrome()` + `.vigilNavigationTitle(...)` + `.vigilInlineNavigationBar()` like `PortfolioManagement/`.
- New `.swift` files under `financeplan/` and `financeplanTests/` are picked up automatically (`PBXFileSystemSynchronizedRootGroup`). Do not edit `project.pbxproj` except for the package pin.
- Tests are XCTest, `@MainActor final class …: XCTestCase`, with mocks that implement the service protocol (see `financeplanTests/BoardsTests.swift`).
- Commit after every task on `feat/pilots-ios`. Do not push.

## Review Focus

1. **Feature switched off (or switched off mid-session).** Every pilots route 404s with body `{"reason":"Not Found"}`. `BaseHTTPClient`'s default `makeStatus` would turn that into `.api("Not Found")` and lose the 404, so the row would stay visible and an alert would read "Not Found". Expected: the entry row and banners disappear silently, and "Stop following" on a follow that 404s counts as already stopped. Pinned in Task 2 (client keeps 404), Task 4 (store hides everything, no error) and Task 5 (stop treats 404 as done).
2. **Free user hits the plan limit.** The 403 body's message is `Upgrade required. feature=pilot_follows plan=free required=pro`. Expected: the paywall opens, and that raw string is never shown. A Pro user at 10 follows (or at the 25-portfolio cap, `feature=portfolio_lists`) gets a plain sentence instead. Pinned in Task 3 (failure mapping) and Task 6 (sheet model).
3. **Double tap on Follow, or a dropped response followed by a retry.** Expected: one follow, not two. The model ignores a second submit while one is in flight, and every attempt from one sheet sends the same `Idempotency-Key` (the backend replays the cached 201). Pinned in Task 2 (header sent) and Task 6 (key reused across attempts).
4. **Disclosure and snapshot days shown one day early west of UTC.** `yyyy-MM-dd` parses to UTC midnight, and formatting in the device time zone shows the previous day in the Americas. Expected: the day as reported. Pinned in Task 3 (`dayText` formats in UTC).
5. **A brand-new follow with no history.** `appliedVersion` 0, no events, zero or one snapshot, or a snapshot with a malformed date. Expected: explanatory empty states rather than a blank chart, and no crash on bad dates. Pinned in Task 3 (`valuePoints` drops bad dates and sorts) and Task 5 (watchlist follows never request snapshots; empty-state copy).

## Codebase facts the tasks rely on

- **No live iOS code decodes `WatchlistItemResponse` or `WatchlistStatus`.** The only decoders are `StockService.fetchWatchlist` / `createWatchlistItem` / `updateWatchlistItem` (`financeplan/Features/Stocks/StockService.swift:266,375,387`) and the CSV preview's `WatchlistCsvImportPreviewItem.status`. Their only callers are `WatchlistViewModel` (`financeplan/Features/Stocks/Watchlist/WatchlistViewModel.swift`) and `WatchlistCSVImportSheet`/`WatchlistCSVImportViewModel`, and nothing in `financeplan/` instantiates them; only `financeplanTests/WatchlistViewModelTests.swift` and `WatchlistCSVImportViewModelTests.swift` do. The stock `Components/AddWatchlistSheet.swift` is also never presented. Crypto watchlists use separate `CryptoWatchlistItemResponse` DTOs, and `fetchWatchlistLists()` decodes `WatchlistListDTOResponse` (`Features/Stocks/ListDTOs.swift:26`), which has no status. **So iOS builds already in users' hands, on 5.16.0, are not a rollout gate for the server writing `exited`.** The 5.17.0 bump below is needed for the pilot DTOs, not to protect a live screen.
- `AGENTS.md` contains only an auto-generated memory dump with no rules. `Docs/architecture.md` describes `ObservableObject` view models, but every feature added since (Boards, Social, Gamification, PortfolioManagement) uses `@Observable`. Follow the newer pattern.
- `Docs/` and `docs/` are the same directory on this case-insensitive filesystem, and git tracks it as `Docs/`.
- `BaseHTTPClient.validateResponse` → `ErrorType.makeStatus(code, message:)`. The default turns any non-2xx with a body message into `.api(message)` and drops the code. `PersistentAssistantHTTPClient` overrides `makeStatus` to keep 409, and this plan does the same for the pilots statuses.
- `APIErrorDecoding.message(from:)` reads Vapor's `{"error":true,"code":…,"reason":…}` and the billing `{"success":false,"code":"upgrade_required","error":"Upgrade required. feature=… plan=…"}` bodies.
- `JSONEncoder.stockPlanShared` encodes keys as snake_case. The backend's `JSONDecoder.backendAPI` accepts both snake_case and camelCase, so request bodies built the Boards way (`encodedParameters`) are accepted.
- Holdings mutations already surface `errorDescription`: `PortfolioViewModel.delete` / `saveEdit` / `saveNewPosition` (`Features/Portfolio/PortfolioViewModel.swift:368-455`) and `StockDetailsScreenViewModel.sellPosition` (`Features/Stocks/StockDetailsScreenViewModel.swift:215-242`), and `StockHTTPClient.Error.api(message)` returns the message unchanged. iOS has no portfolio-transaction editing UI. Task 9 pins this behavior with tests rather than adding code.
- Paywall: `PaywallView(billingManager:)` in a `.sheet`. Pro check: `@InjectedObservable(\.billingManager) private var billingManager` with `billingManager.isPro`.
- Test command (substitute the class name):
  `cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots && xcodebuild test -project financeplan.xcodeproj -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:financeplanTests/<TestClass> 2>&1 | tail -25`
  Full unit suite: `make ios-test`. Build only: `make ios-build`.

## File map

| File | Responsibility | Task |
|---|---|---|
| `financeplan.xcodeproj/project.pbxproj:934`, `…/swiftpm/Package.resolved:174-180` | StockPlanShared 5.17.0 pin | 1 |
| `financeplan/API/Pilots/PilotsEndpoints.swift` | One `Endpoint` per route | 2 |
| `financeplan/API/Pilots/PilotsHTTPClient.swift` | Client + `Error` that keeps 400/403/404/409/422 | 2 |
| `financeplan/API/Pilots/Container+PilotsFactories.swift` | `pilotsService`, `pilotsStore` (singleton) | 2, 4 |
| `financeplan/Features/Pilots/PilotsService.swift` | `PilotsServicing` + `DefaultPilotsService` | 2 |
| `financeplan/Features/Pilots/PilotFollowRules.swift` | Limits, capital validation, POST failure mapping | 3 |
| `financeplan/Features/Pilots/PilotFormatting.swift` | All display text, dates, value points | 3 |
| `financeplan/Features/Pilots/PilotsStore.swift` | Feature availability, catalogue, follows | 4, 8 |
| `financeplan/Features/Pilots/PilotFollowDetailModel.swift` | Events, snapshots, pause/resume, stop | 5 |
| `financeplan/Features/Pilots/PilotFollowDetailScreen.swift` | Follow detail UI + `PilotFollowRow` | 5 |
| `financeplan/Features/Pilots/PilotFollowValueChart.swift` | Snapshot value chart | 5 |
| `financeplan/Features/Pilots/FollowPilotModel.swift` | Follow form state + submit | 6 |
| `financeplan/Features/Pilots/FollowPilotSheet.swift` | Target, capital, disclaimer, paywall | 6 |
| `financeplan/Features/Pilots/PilotDetailModel.swift` | Pilot detail load | 7 |
| `financeplan/Features/Pilots/PilotDetailScreen.swift` | Weights, disclosures, puts and lag notes, Follow | 7 |
| `financeplan/Features/Pilots/PilotsBrowseScreen.swift` | Following + politicians + funds | 7 |
| `financeplan/Features/Pilots/PilotsEntryPoints.swift` | `PilotsEntryRow`, `PilotFollowBanner` | 8 |
| `financeplan/Features/PortfolioManagement/PortfolioWorkspaceScreen.swift` | "Follow a pilot" row | 8 |
| `financeplan/Features/PortfolioManagement/PortfolioDetailScreen.swift` | "Following <pilot>" banner | 8 |
| `financeplanTests/PilotsSharedContractTests.swift` | DTO decoding on 5.17.0 | 1 |
| `financeplanTests/PilotsHTTPClientTests.swift` | Paths, verbs, bodies, headers, statuses | 2 |
| `financeplanTests/PilotsTestSupport.swift` | `MockPilotsService` + fixtures | 3 |
| `financeplanTests/PilotsLogicTests.swift` | Rules + formatting | 3 |
| `financeplanTests/PilotsStoreTests.swift` | Store | 4, 8 |
| `financeplanTests/PilotFollowDetailModelTests.swift` | Follow detail model | 5 |
| `financeplanTests/FollowPilotModelTests.swift` | Follow sheet model | 6 |
| `financeplanTests/PilotDetailModelTests.swift` | Pilot detail model | 7 |
| `financeplanTests/PilotManagedPortfolioErrorTests.swift`, `financeplanTests/PortfolioViewModelTests.swift` | 409 managed-portfolio message | 9 |

---

### Task 1: Pin StockPlanShared to exact 5.17.0

**Files:**
- Modify: `financeplan.xcodeproj/project.pbxproj:934`
- Modify: `financeplan.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:174-180` (regenerated, not hand-edited)
- Test: `financeplanTests/PilotsSharedContractTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: the `StockPlanShared` pilot DTOs (listed in Global Constraints) and `WatchlistStatus.exited`, available to every later task.

- [ ] **Step 1: Write the failing test**

Create `financeplanTests/PilotsSharedContractTests.swift`:

```swift
import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

/// Pins the StockPlanShared version the pilots feature needs: these types and
/// the lenient `WatchlistStatus` exist from 5.17.0.
final class PilotsSharedContractTests: XCTestCase {
  func testWatchlistItemWithExitedStatusDecodes() throws {
    let json = Data(#"{"id":"w1","symbol":"NVDA","note":"Pelosi sold 2026-09-30","status":"exited"}"#.utf8)
    let item = try JSONDecoder.stockPlanShared.decode(WatchlistItemResponse.self, from: json)
    XCTAssertEqual(item.status, .exited)
  }

  func testUnknownWatchlistStatusDecodesAsActive() throws {
    let json = Data(#"{"id":"w1","symbol":"NVDA","status":"something_new"}"#.utf8)
    let item = try JSONDecoder.stockPlanShared.decode(WatchlistItemResponse.self, from: json)
    XCTAssertEqual(item.status, .active)
  }

  func testPilotDetailDecodesFromTheServerShape() throws {
    let json = Data(#"""
    {"pilot":{"slug":"nancy-pelosi","displayName":"Nancy Pelosi","kind":"politician","chamber":"house","updatedAt":"2026-09-30T12:00:00Z","holdingsCount":2},
     "weights":[{"symbol":"NVDA","weight":0.6},{"symbol":"AAPL","weight":0.4}],
     "skippedPuts":1,
     "recentDisclosures":[{"symbol":"NVDA","side":"buy","instrument":"call","transactionDate":"2026-09-14","disclosureDate":"2026-09-28","amountMin":1001,"amountMax":15000,"period":null}],
     "lagNote":"Congressional trades are disclosed up to 45 days after they happen."}
    """#.utf8)
    let detail = try JSONDecoder.stockPlanShared.decode(PilotDetail.self, from: json)
    XCTAssertEqual(detail.pilot.kind, .politician)
    XCTAssertEqual(detail.weights.map(\.symbol), ["NVDA", "AAPL"])
    XCTAssertEqual(detail.skippedPuts, 1)
    XCTAssertEqual(detail.recentDisclosures.first?.instrument, "call")
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots && xcodebuild test -project financeplan.xcodeproj -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:financeplanTests/PilotsSharedContractTests 2>&1 | tail -25`
Expected: build FAILS with `type 'WatchlistStatus' has no member 'exited'` and `cannot find 'PilotDetail' in scope` (still on 5.16.0).

- [ ] **Step 3: Bump the pin and re-resolve**

```bash
cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots
sed -i '' 's/version = 5\.16\.0;/version = 5.17.0;/' financeplan.xcodeproj/project.pbxproj
grep -n -A5 'XCRemoteSwiftPackageReference "norviq-shared" \*/ = {' financeplan.xcodeproj/project.pbxproj
xcodebuild -resolvePackageDependencies -project financeplan.xcodeproj -scheme financeplan 2>&1 | tail -5
grep -n -A6 '"identity" : "norviq-shared"' financeplan.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
git diff --stat
```

Expected: the pbxproj block shows `kind = exactVersion;` / `version = 5.17.0;`. `Package.resolved` shows `"revision" : "8d9cf53edb1605b8395cc8e52bc4818938f9df89"` and `"version" : "5.17.0"`. `git diff --stat` lists only `project.pbxproj` and `Package.resolved`, and within `Package.resolved` only the `norviq-shared` pin and `originHash` change. If any other pin moved, stop and report it rather than committing.

- [ ] **Step 4: Run test to verify it passes**

Run: the Step 2 command.
Expected: `** TEST SUCCEEDED **`, 3 tests passed.

- [ ] **Step 5: Run the whole unit suite once to catch bump fallout**

Run: `cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots && make ios-test 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`. If a test unrelated to pilots fails, run the same command on `main` (`git stash; git checkout main; make ios-test; git checkout feat/pilots-ios; git stash pop`). Only treat it as bump fallout if it passes on `main`.

- [ ] **Step 6: Commit**

```bash
git add financeplan.xcodeproj/project.pbxproj financeplan.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved financeplanTests/PilotsSharedContractTests.swift
git commit -m "chore(pilots): pin StockPlanShared 5.17.0 for pilot DTOs"
```

---

### Task 2: Pilots API client, service and factory

**Files:**
- Create: `financeplan/API/Pilots/PilotsEndpoints.swift`
- Create: `financeplan/API/Pilots/PilotsHTTPClient.swift`
- Create: `financeplan/API/Pilots/Container+PilotsFactories.swift`
- Create: `financeplan/Features/Pilots/PilotsService.swift`
- Test: `financeplanTests/PilotsHTTPClientTests.swift`

**Interfaces:**
- Consumes: StockPlanShared pilot DTOs (Task 1); `BaseHTTPClient`, `HTTPClientError`, `HTTPClientSession`, `EmptyAPIResponse`; `StockService.fetchWatchlistLists() -> [WatchlistListDTOResponse]`; `Container.appEnvironment`, `Container.authSessionStore`, `Container.stockService`.
- Produces:
  - `PilotsHTTPClient.Error` with `case rejected(status: Int, message: String?)` for 400/403/404/409/422, plus `invalidResponse`, `invalidStatus(Int)`, `unauthorized(String?)`, `api(String)`. `statusCode` returns the status for `rejected` and `invalidStatus`.
  - `protocol PilotsServicing: Sendable` with:
    - `func pilots() async throws -> [PilotSummary]`
    - `func pilot(slug: String) async throws -> PilotDetail`
    - `func follows() async throws -> [PilotFollowResponse]`
    - `func follow(_ request: PilotFollowCreateRequest, idempotencyKey: String) async throws -> PilotFollowResponse`
    - `func setStatus(_ status: PilotFollowStatus, followId: String) async throws -> PilotFollowResponse`
    - `func stopFollowing(followId: String) async throws`
    - `func events(followId: String) async throws -> [PilotFollowEventResponse]`
    - `func snapshots(followId: String) async throws -> [PilotFollowSnapshotResponse]`
    - `func watchlists() async throws -> [WatchlistListDTOResponse]`
  - `Container.pilotsService: Factory<any PilotsServicing>`.

- [ ] **Step 1: Write the failing test**

Create `financeplanTests/PilotsHTTPClientTests.swift`:

```swift
import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

private final class PilotsMockURLProtocol: URLProtocol {
  struct Recorded {
    let request: URLRequest
    let body: Data?
  }

  /// Returns (status, JSON body) for a request.
  nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, String))?
  nonisolated(unsafe) static var recorded: [Recorded] = []

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.recorded.append(Recorded(request: request, body: Self.readBody(of: request)))
    guard let handler = Self.handler, let url = request.url else {
      fatalError("PilotsMockURLProtocol.handler must be set before use")
    }
    let (status, body) = handler(request)
    guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"]) else {
      fatalError("Could not build HTTPURLResponse")
    }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}

  private static func readBody(of request: URLRequest) -> Data? {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
      let count = stream.read(&buffer, maxLength: buffer.count)
      guard count > 0 else { break }
      data.append(buffer, count: count)
    }
    return data
  }
}

private let followJSON = #"""
{"id":"11111111-1111-1111-1111-111111111111",
 "pilot":{"slug":"nancy-pelosi","displayName":"Nancy Pelosi","kind":"politician","chamber":"house","updatedAt":"2026-09-30T12:00:00Z","holdingsCount":12},
 "targetKind":"portfolio","portfolioListId":"22222222-2222-2222-2222-222222222222","watchlistListId":null,
 "startingCapital":10000,"currency":"USD","status":"active","appliedVersion":3,"createdAt":"2026-10-01T09:00:00Z"}
"""#

@MainActor
final class PilotsHTTPClientTests: XCTestCase {
  nonisolated(unsafe) private var client: PilotsHTTPClient!

  override func setUp() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [PilotsMockURLProtocol.self]
    PilotsMockURLProtocol.recorded = []
    client = PilotsHTTPClient(
      baseURL: URL(string: "https://api.example.com")!,
      session: URLSession(configuration: config),
      authTokenProvider: { "token" }
    )
  }

  override func tearDown() async throws {
    PilotsMockURLProtocol.handler = nil
    PilotsMockURLProtocol.recorded = []
    client = nil
  }

  private var lastRequest: URLRequest? { PilotsMockURLProtocol.recorded.last?.request }

  func testListPilotsDecodesSummariesWithBearerToken() async throws {
    PilotsMockURLProtocol.handler = { _ in
      (200, #"[{"slug":"nancy-pelosi","displayName":"Nancy Pelosi","kind":"politician","chamber":"house","updatedAt":"2026-09-30T12:00:00Z","holdingsCount":12},{"slug":"berkshire","displayName":"Berkshire Hathaway","kind":"fund","chamber":null,"updatedAt":null,"holdingsCount":0}]"#)
    }

    let pilots = try await client.pilots()

    XCTAssertEqual(pilots.map(\.slug), ["nancy-pelosi", "berkshire"])
    XCTAssertEqual(pilots.last?.kind, .fund)
    XCTAssertEqual(pilots.last?.holdingsCount, 0)
    XCTAssertEqual(lastRequest?.httpMethod, "GET")
    XCTAssertEqual(lastRequest?.url?.path, "/v1/pilots")
    XCTAssertEqual(lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer token")
  }

  func testFeatureOffKeepsThe404SoCallersCanHideEntryPoints() async {
    PilotsMockURLProtocol.handler = { _ in (404, #"{"error":true,"code":"not_found","reason":"Not Found"}"#) }

    do {
      _ = try await client.pilots()
      XCTFail("Expected a 404")
    } catch let error as PilotsHTTPClient.Error {
      XCTAssertEqual(error, .rejected(status: 404, message: "Not Found"))
      XCTAssertEqual(error.statusCode, 404)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testUpgradeRequiredKeepsThe403AndTheServerReason() async {
    PilotsMockURLProtocol.handler = { _ in
      (403, #"{"success":false,"code":"upgrade_required","error":"Upgrade required. feature=pilot_follows plan=free required=pro","feature":"pilot_follows","plan":"free","requiredPlan":"pro"}"#)
    }
    let request = PilotFollowCreateRequest(pilotSlug: "nancy-pelosi", targetKind: .watchlist, portfolioListId: nil, watchlistListId: nil, startingCapital: nil)

    do {
      _ = try await client.follow(request, idempotencyKey: "k")
      XCTFail("Expected a 403")
    } catch let error as PilotsHTTPClient.Error {
      XCTAssertEqual(error, .rejected(status: 403, message: "Upgrade required. feature=pilot_follows plan=free required=pro"))
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testNonEmptyTargetKeepsThe422Reason() async {
    PilotsMockURLProtocol.handler = { _ in (422, #"{"error":true,"code":"unprocessable_entity","reason":"Choose an empty watchlist, or let Norviq create one."}"#) }
    let request = PilotFollowCreateRequest(pilotSlug: "nancy-pelosi", targetKind: .watchlist, portfolioListId: nil, watchlistListId: "33333333-3333-3333-3333-333333333333", startingCapital: nil)

    do {
      _ = try await client.follow(request, idempotencyKey: "k")
      XCTFail("Expected a 422")
    } catch let error as PilotsHTTPClient.Error {
      XCTAssertEqual(error, .rejected(status: 422, message: "Choose an empty watchlist, or let Norviq create one."))
      XCTAssertEqual(error.errorDescription, "Choose an empty watchlist, or let Norviq create one.")
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testFollowPostsTheRequestWithAnIdempotencyKey() async throws {
    PilotsMockURLProtocol.handler = { _ in (201, followJSON) }
    let request = PilotFollowCreateRequest(pilotSlug: "nancy-pelosi", targetKind: .portfolio, portfolioListId: nil, watchlistListId: nil, startingCapital: 10_000)

    let follow = try await client.follow(request, idempotencyKey: "key-1")

    XCTAssertEqual(follow.id, "11111111-1111-1111-1111-111111111111")
    XCTAssertEqual(follow.appliedVersion, 3)
    let sent = try XCTUnwrap(PilotsMockURLProtocol.recorded.last)
    XCTAssertEqual(sent.request.httpMethod, "POST")
    XCTAssertEqual(sent.request.url?.path, "/v1/pilot-follows")
    // If this fails, the `headers` declaration in PilotsEndpoints does not match
    // AnyAPI's `Endpoint.headers` requirement. Copy `StockEnpoints.swift:398` exactly.
    XCTAssertEqual(sent.request.value(forHTTPHeaderField: "Idempotency-Key"), "key-1")
    let body = try XCTUnwrap(sent.body)
    XCTAssertEqual(try JSONDecoder.stockPlanShared.decode(PilotFollowCreateRequest.self, from: body), request)
  }

  func testPauseSendsPatchWithTheNewStatus() async throws {
    PilotsMockURLProtocol.handler = { _ in (200, followJSON.replacingOccurrences(of: #""status":"active""#, with: #""status":"paused""#)) }

    let follow = try await client.setStatus(.paused, followId: "11111111-1111-1111-1111-111111111111")

    XCTAssertEqual(follow.status, .paused)
    let sent = try XCTUnwrap(PilotsMockURLProtocol.recorded.last)
    XCTAssertEqual(sent.request.httpMethod, "PATCH")
    XCTAssertEqual(sent.request.url?.path, "/v1/pilot-follows/11111111-1111-1111-1111-111111111111")
    let body = try XCTUnwrap(sent.body)
    XCTAssertEqual(try JSONDecoder.stockPlanShared.decode(PilotFollowUpdateRequest.self, from: body).status, .paused)
  }

  func testStopSendsDeleteAndAcceptsANoContentResponse() async throws {
    PilotsMockURLProtocol.handler = { _ in (204, "") }

    try await client.stopFollowing(followId: "11111111-1111-1111-1111-111111111111")

    XCTAssertEqual(lastRequest?.httpMethod, "DELETE")
    XCTAssertEqual(lastRequest?.url?.path, "/v1/pilot-follows/11111111-1111-1111-1111-111111111111")
  }

  func testEventsAndSnapshotsDecodeFromTheirOwnPaths() async throws {
    PilotsMockURLProtocol.handler = { request in
      if request.url?.path.hasSuffix("/events") == true {
        return (200, #"[{"id":"e1","bookVersion":3,"kind":"buy","symbol":"NVDA","quantity":12.5,"price":123.45,"pricedAt":"2026-09-30T14:00:00Z","note":"Pelosi bought 2026-09-14"}]"#)
      }
      return (200, #"[{"date":"2026-09-30","value":10000,"cash":120.5},{"date":"2026-10-01","value":10420,"cash":120.5}]"#)
    }

    let events = try await client.events(followId: "f1")
    let snapshots = try await client.snapshots(followId: "f1")

    XCTAssertEqual(events.first?.kind, "buy")
    XCTAssertEqual(events.first?.quantity, 12.5)
    XCTAssertEqual(snapshots.map(\.date), ["2026-09-30", "2026-10-01"])
    XCTAssertEqual(PilotsMockURLProtocol.recorded.map { $0.request.url?.path }, ["/v1/pilot-follows/f1/events", "/v1/pilot-follows/f1/snapshots"])
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots && xcodebuild test -project financeplan.xcodeproj -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:financeplanTests/PilotsHTTPClientTests 2>&1 | tail -25`
Expected: build FAILS with `cannot find 'PilotsHTTPClient' in scope`.

- [ ] **Step 3: Write the endpoints**

Create `financeplan/API/Pilots/PilotsEndpoints.swift`:

```swift
import AnyAPI
import Foundation
import StockPlanShared

// Pilot follows. Contract: StockPlanShared PilotDTOs; routes in the backend's
// Pilots/PilotController.swift. Every route returns 404 while PILOTS_ENABLED is off.

private nonisolated func pilotParameters(_ payload: some Encodable) throws -> Parameters {
  let data = try JSONEncoder.stockPlanShared.encode(payload)
  return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
}

nonisolated struct ListPilotsEndpoint: Endpoint {
  typealias Response = [PilotSummary]
  var method: HTTPMethod { .get }
  var path: String { "/v1/pilots" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetPilotEndpoint: Endpoint {
  typealias Response = PilotDetail
  let slug: String
  var method: HTTPMethod { .get }
  var path: String { "/v1/pilots/\(slug)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct ListPilotFollowsEndpoint: Endpoint {
  typealias Response = [PilotFollowResponse]
  var method: HTTPMethod { .get }
  var path: String { "/v1/pilot-follows" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

/// The backend caches a successful response per `Idempotency-Key` for 24h, so
/// a retry after a dropped response replays the first follow instead of
/// creating a second one.
nonisolated struct CreatePilotFollowEndpoint: Endpoint {
  typealias Response = PilotFollowResponse
  let payload: PilotFollowCreateRequest
  let idempotencyKey: String
  var method: HTTPMethod { .post }
  var path: String { "/v1/pilot-follows" }
  var decoder: JSONDecoder { .stockPlanShared }
  var headers: [(String, String)] { [("Idempotency-Key", idempotencyKey)] }
  func asParameters() throws -> Parameters { try pilotParameters(payload) }
}

nonisolated struct UpdatePilotFollowEndpoint: Endpoint {
  typealias Response = PilotFollowResponse
  let followId: String
  let payload: PilotFollowUpdateRequest
  var method: HTTPMethod { .patch }
  var path: String { "/v1/pilot-follows/\(followId)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { try pilotParameters(payload) }
}

nonisolated struct DeletePilotFollowEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let followId: String
  var method: HTTPMethod { .delete }
  var path: String { "/v1/pilot-follows/\(followId)" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct ListPilotFollowEventsEndpoint: Endpoint {
  typealias Response = [PilotFollowEventResponse]
  let followId: String
  var method: HTTPMethod { .get }
  var path: String { "/v1/pilot-follows/\(followId)/events" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct ListPilotFollowSnapshotsEndpoint: Endpoint {
  typealias Response = [PilotFollowSnapshotResponse]
  let followId: String
  var method: HTTPMethod { .get }
  var path: String { "/v1/pilot-follows/\(followId)/snapshots" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}
```

- [ ] **Step 4: Write the client**

Create `financeplan/API/Pilots/PilotsHTTPClient.swift`:

```swift
import AnyAPI
import Foundation
import OSLog
import StockPlanShared

nonisolated struct PilotsHTTPClient: Sendable {
  enum Error: HTTPClientError {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)
    /// A 4xx the pilots UI must tell apart, with the server's reason:
    /// 400 bad capital, 403 upgrade or token scope, 404 missing or feature off,
    /// 409 no trades yet or duplicate follow, 422 target not empty.
    case rejected(status: Int, message: String?)

    nonisolated var errorDescription: String? {
      switch self {
      case .invalidResponse: return "Invalid server response."
      case let .invalidStatus(code): return "Request failed (\(code))."
      case let .unauthorized(message): return message ?? "Your session expired. Please sign in again."
      case let .api(message): return message
      case let .rejected(status, message): return message ?? "Request failed (\(status))."
      }
    }

    nonisolated var statusCode: Int? {
      switch self {
      case let .invalidStatus(code): return code
      case let .rejected(status, _): return status
      default: return nil
      }
    }

    nonisolated static func == (lhs: Error, rhs: Error) -> Bool {
      switch (lhs, rhs) {
      case (.invalidResponse, .invalidResponse): return true
      case let (.invalidStatus(l), .invalidStatus(r)): return l == r
      case let (.unauthorized(l), .unauthorized(r)): return l == r
      case let (.api(l), .api(r)): return l == r
      case let (.rejected(ls, lm), .rejected(rs, rm)): return ls == rs && lm == rm
      default: return false
      }
    }

    static func makeInvalidResponse() -> Error { .invalidResponse }
    static func makeInvalidStatus(_ code: Int) -> Error { .invalidStatus(code) }
    static func makeUnauthorized(_ message: String?) -> Error { .unauthorized(message) }
    static func makeAPI(_ message: String) -> Error { .api(message) }
    static func makeStatus(_ code: Int, message: String?) -> Error {
      if [400, 403, 404, 409, 422].contains(code) { return .rejected(status: code, message: message) }
      if let message, !message.isEmpty { return .api(message) }
      return .invalidStatus(code)
    }
  }

  private let client: BaseHTTPClient

  init(
    baseURL: URL,
    session: any HTTPClientSession = URLSession.shared,
    authTokenProvider: @escaping @Sendable () async -> String? = { nil }
  ) {
    self.client = BaseHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: authTokenProvider,
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "PilotsHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  func pilots() async throws -> [PilotSummary] {
    try await client.call(ListPilotsEndpoint(), errorType: Error.self)
  }

  func pilot(slug: String) async throws -> PilotDetail {
    try await client.call(GetPilotEndpoint(slug: slug), errorType: Error.self)
  }

  func follows() async throws -> [PilotFollowResponse] {
    try await client.call(ListPilotFollowsEndpoint(), errorType: Error.self)
  }

  func follow(_ request: PilotFollowCreateRequest, idempotencyKey: String) async throws -> PilotFollowResponse {
    try await client.call(CreatePilotFollowEndpoint(payload: request, idempotencyKey: idempotencyKey), errorType: Error.self)
  }

  func setStatus(_ status: PilotFollowStatus, followId: String) async throws -> PilotFollowResponse {
    try await client.call(
      UpdatePilotFollowEndpoint(followId: followId, payload: PilotFollowUpdateRequest(status: status)),
      errorType: Error.self
    )
  }

  func stopFollowing(followId: String) async throws {
    try await client.callWithoutResponse(DeletePilotFollowEndpoint(followId: followId), errorType: Error.self)
  }

  func events(followId: String) async throws -> [PilotFollowEventResponse] {
    try await client.call(ListPilotFollowEventsEndpoint(followId: followId), errorType: Error.self)
  }

  func snapshots(followId: String) async throws -> [PilotFollowSnapshotResponse] {
    try await client.call(ListPilotFollowSnapshotsEndpoint(followId: followId), errorType: Error.self)
  }
}
```

- [ ] **Step 5: Write the service and factory**

Create `financeplan/Features/Pilots/PilotsService.swift`:

```swift
import Factory
import Foundation
import StockPlanShared

protocol PilotsServicing: Sendable {
  func pilots() async throws -> [PilotSummary]
  func pilot(slug: String) async throws -> PilotDetail
  func follows() async throws -> [PilotFollowResponse]
  func follow(_ request: PilotFollowCreateRequest, idempotencyKey: String) async throws -> PilotFollowResponse
  func setStatus(_ status: PilotFollowStatus, followId: String) async throws -> PilotFollowResponse
  func stopFollowing(followId: String) async throws
  func events(followId: String) async throws -> [PilotFollowEventResponse]
  func snapshots(followId: String) async throws -> [PilotFollowSnapshotResponse]
  /// The viewer's watchlists, for picking an existing (empty) one as a target.
  func watchlists() async throws -> [WatchlistListDTOResponse]
}

struct DefaultPilotsService: PilotsServicing {
  let client: PilotsHTTPClient

  init(environmentManager: AppEnvironmentManager) {
    self.client = PilotsHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: URLSession.shared,
      authTokenProvider: { await Container.shared.authSessionStore().authToken }
    )
  }

  func pilots() async throws -> [PilotSummary] { try await client.pilots() }
  func pilot(slug: String) async throws -> PilotDetail { try await client.pilot(slug: slug) }
  func follows() async throws -> [PilotFollowResponse] { try await client.follows() }
  func follow(_ request: PilotFollowCreateRequest, idempotencyKey: String) async throws -> PilotFollowResponse {
    try await client.follow(request, idempotencyKey: idempotencyKey)
  }
  func setStatus(_ status: PilotFollowStatus, followId: String) async throws -> PilotFollowResponse {
    try await client.setStatus(status, followId: followId)
  }
  func stopFollowing(followId: String) async throws { try await client.stopFollowing(followId: followId) }
  func events(followId: String) async throws -> [PilotFollowEventResponse] { try await client.events(followId: followId) }
  func snapshots(followId: String) async throws -> [PilotFollowSnapshotResponse] { try await client.snapshots(followId: followId) }
  func watchlists() async throws -> [WatchlistListDTOResponse] {
    try await Container.shared.stockService().fetchWatchlistLists()
  }
}
```

Create `financeplan/API/Pilots/Container+PilotsFactories.swift`:

```swift
import Factory
import Foundation

extension Container {
  var pilotsService: Factory<any PilotsServicing> {
    self { @MainActor in
      DefaultPilotsService(environmentManager: self.appEnvironment())
    }
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: the Step 2 command.
Expected: `** TEST SUCCEEDED **`, 8 tests passed.

- [ ] **Step 7: Commit**

```bash
git add financeplan/API/Pilots financeplan/Features/Pilots/PilotsService.swift financeplanTests/PilotsHTTPClientTests.swift
git commit -m "feat(pilots): iOS pilots API client and service"
```

---

### Task 3: Follow rules, failure mapping and display formatting

**Files:**
- Create: `financeplan/Features/Pilots/PilotFollowRules.swift`
- Create: `financeplan/Features/Pilots/PilotFormatting.swift`
- Create: `financeplanTests/PilotsTestSupport.swift`
- Test: `financeplanTests/PilotsLogicTests.swift`

**Interfaces:**
- Consumes: `PilotsHTTPClient.Error.rejected(status:message:)`, `PilotsServicing` (Task 2).
- Produces:
  - `enum PilotFollowRules` with `static let freeFollowLimit = 1`, `static let proFollowLimit = 10`, `static let maxStartingCapital: Double = 10_000_000`, `enum Block: Equatable { case noTradesYet, needsPro, atLimit }`, `static func block(for pilot: PilotSummary, isPro: Bool, followCount: Int) -> Block?`, `static func capitalProblem(_ capital: Double?) -> String?`.
  - `enum PilotFollowFailure: Equatable { case needsPro; case message(String) }` with `static func from(_ error: any Error, isPro: Bool) -> PilotFollowFailure`.
  - `struct PilotValuePoint: Identifiable, Equatable { let date: Date; let value: Double }`.
  - `enum PilotFormatting` with: `day(_:) -> Date?`, `instant(_:) -> Date?`, `dayText(_:locale:) -> String`, `instantText(_:locale:timeZone:) -> String`, `weight(_:locale:) -> String`, `money(_:currency:wholeUnits:locale:) -> String`, `signedPercent(_:locale:) -> String`, `performance(start:latest:) -> Double?`, `valuePoints(_:) -> [PilotValuePoint]`, `kindLabel(_:) -> String`, `subtitle(for:) -> String`, `skippedPutsNote(_:) -> String?`, `disclosureTitle(_:) -> String`, `isSkippedPut(_:) -> Bool`, `amountRange(min:max:locale:) -> String?`, `disclosureDetail(_:locale:) -> String?`, `followSubtitle(_:locale:) -> String`, `eventTitle(_:locale:) -> String`, `eventDetail(_:currency:locale:timeZone:) -> String`, `eventSymbolName(_:) -> String`.
  - Test support: `MockPilotsService` and `.fixture(...)` factories on `PilotSummary`, `PilotDetail`, `PilotFollowResponse`, `PilotFollowEventResponse` (used by Tasks 4–8).

- [ ] **Step 1: Write the test support file**

Create `financeplanTests/PilotsTestSupport.swift`:

```swift
import Foundation
import StockPlanShared
@testable import financeplan

final class MockPilotsService: PilotsServicing, @unchecked Sendable {
  var pilotsResult: Result<[PilotSummary], Error> = .success([.fixture()])
  var detailResult: Result<PilotDetail, Error> = .success(.fixture())
  var followsResult: Result<[PilotFollowResponse], Error> = .success([])
  var followResult: Result<PilotFollowResponse, Error> = .success(.fixture())
  var statusError: Error?
  var stopError: Error?
  var eventsResult: Result<[PilotFollowEventResponse], Error> = .success([])
  var snapshotsResult: Result<[PilotFollowSnapshotResponse], Error> = .success([])
  var watchlistsResult: Result<[WatchlistListDTOResponse], Error> = .success([])

  private(set) var followRequests: [PilotFollowCreateRequest] = []
  private(set) var idempotencyKeys: [String] = []
  private(set) var statusRequests: [PilotFollowStatus] = []
  private(set) var stoppedFollowIds: [String] = []
  private(set) var snapshotCalls = 0

  func pilots() async throws -> [PilotSummary] { try pilotsResult.get() }
  func pilot(slug: String) async throws -> PilotDetail { try detailResult.get() }
  func follows() async throws -> [PilotFollowResponse] { try followsResult.get() }

  func follow(_ request: PilotFollowCreateRequest, idempotencyKey: String) async throws -> PilotFollowResponse {
    followRequests.append(request)
    idempotencyKeys.append(idempotencyKey)
    return try followResult.get()
  }

  func setStatus(_ status: PilotFollowStatus, followId: String) async throws -> PilotFollowResponse {
    statusRequests.append(status)
    if let statusError { throw statusError }
    return .fixture(id: followId, status: status)
  }

  func stopFollowing(followId: String) async throws {
    if let stopError { throw stopError }
    stoppedFollowIds.append(followId)
  }

  func events(followId: String) async throws -> [PilotFollowEventResponse] { try eventsResult.get() }

  func snapshots(followId: String) async throws -> [PilotFollowSnapshotResponse] {
    snapshotCalls += 1
    return try snapshotsResult.get()
  }

  func watchlists() async throws -> [WatchlistListDTOResponse] { try watchlistsResult.get() }
}

extension PilotSummary {
  static func fixture(
    slug: String = "nancy-pelosi",
    displayName: String = "Nancy Pelosi",
    kind: PilotKind = .politician,
    holdingsCount: Int = 12
  ) -> PilotSummary {
    PilotSummary(
      slug: slug,
      displayName: displayName,
      kind: kind,
      chamber: kind == .politician ? "house" : nil,
      updatedAt: "2026-09-30T12:00:00Z",
      holdingsCount: holdingsCount
    )
  }
}

extension PilotDetail {
  static func fixture(pilot: PilotSummary = .fixture(), skippedPuts: Int = 0) -> PilotDetail {
    PilotDetail(
      pilot: pilot,
      weights: [PilotWeight(symbol: "NVDA", weight: 0.6), PilotWeight(symbol: "AAPL", weight: 0.4)],
      skippedPuts: skippedPuts,
      recentDisclosures: [
        PilotDisclosureItem(
          symbol: "NVDA", side: "buy", instrument: "call", transactionDate: "2026-09-14",
          disclosureDate: "2026-09-28", amountMin: 1001, amountMax: 15000, period: nil
        )
      ],
      lagNote: "Congressional trades are disclosed up to 45 days after they happen."
    )
  }
}

extension PilotFollowResponse {
  static func fixture(
    id: String = "11111111-1111-1111-1111-111111111111",
    pilot: PilotSummary = .fixture(),
    targetKind: PilotFollowTargetKind = .portfolio,
    portfolioListId: String = "22222222-2222-2222-2222-222222222222",
    startingCapital: Double = 10_000,
    status: PilotFollowStatus = .active,
    appliedVersion: Int = 1
  ) -> PilotFollowResponse {
    PilotFollowResponse(
      id: id,
      pilot: pilot,
      targetKind: targetKind,
      portfolioListId: targetKind == .portfolio ? portfolioListId : nil,
      watchlistListId: targetKind == .watchlist ? "33333333-3333-3333-3333-333333333333" : nil,
      startingCapital: targetKind == .portfolio ? startingCapital : nil,
      currency: "USD",
      status: status,
      appliedVersion: appliedVersion,
      createdAt: "2026-10-01T09:00:00Z"
    )
  }
}

extension PilotFollowEventResponse {
  static func fixture(
    id: String = "e1",
    kind: String = "buy",
    symbol: String = "NVDA",
    quantity: Double? = 12.5,
    price: Double? = 123.45,
    note: String? = nil
  ) -> PilotFollowEventResponse {
    PilotFollowEventResponse(
      id: id, bookVersion: 1, kind: kind, symbol: symbol, quantity: quantity,
      price: price, pricedAt: "2026-09-30T14:00:00Z", note: note
    )
  }
}
```

- [ ] **Step 2: Write the failing test**

Create `financeplanTests/PilotsLogicTests.swift`:

```swift
import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class PilotFollowRulesTests: XCTestCase {
  func testAPilotWithNoTradesCannotBeFollowedOnAnyPlan() {
    let empty = PilotSummary.fixture(holdingsCount: 0)
    XCTAssertEqual(PilotFollowRules.block(for: empty, isPro: true, followCount: 0), .noTradesYet)
    XCTAssertEqual(PilotFollowRules.block(for: empty, isPro: false, followCount: 0), .noTradesYet)
  }

  func testFreeGetsOneFollowAndProGetsTen() {
    let pilot = PilotSummary.fixture()
    XCTAssertNil(PilotFollowRules.block(for: pilot, isPro: false, followCount: 0))
    XCTAssertEqual(PilotFollowRules.block(for: pilot, isPro: false, followCount: 1), .needsPro)
    XCTAssertNil(PilotFollowRules.block(for: pilot, isPro: true, followCount: 9))
    XCTAssertEqual(PilotFollowRules.block(for: pilot, isPro: true, followCount: 10), .atLimit)
  }

  func testStartingCapitalMustBeAboveZeroAndAtMostTenMillion() {
    XCTAssertEqual(PilotFollowRules.capitalProblem(nil), "Enter a starting amount.")
    XCTAssertEqual(PilotFollowRules.capitalProblem(0), "Enter an amount above zero.")
    XCTAssertEqual(PilotFollowRules.capitalProblem(10_000_001), "The most you can start with is $10,000,000.")
    XCTAssertNil(PilotFollowRules.capitalProblem(10_000))
    XCTAssertNil(PilotFollowRules.capitalProblem(10_000_000))
  }
}

@MainActor
final class PilotFollowFailureTests: XCTestCase {
  private func rejected(_ status: Int, _ message: String?) -> PilotsHTTPClient.Error {
    .rejected(status: status, message: message)
  }

  func testUpgradeRequiredOpensThePaywallForFreeAndNeverShowsTheRawReason() {
    let error = rejected(403, "Upgrade required. feature=pilot_follows plan=free required=pro")
    XCTAssertEqual(PilotFollowFailure.from(error, isPro: false), .needsPro)
    XCTAssertEqual(
      PilotFollowFailure.from(error, isPro: true),
      .message("You're following 10 pilots, the most your plan allows. Stop following one to add another.")
    )
  }

  func testPortfolioCapExplainsArchiving() {
    let error = rejected(403, "Upgrade required. feature=portfolio_lists plan=pro limit=25 current=25")
    XCTAssertEqual(
      PilotFollowFailure.from(error, isPro: true),
      .message("You've reached the portfolio limit for your plan. Archive a portfolio, then try again.")
    )
  }

  func testA403ThatIsNotAnUpgradeIsAScopeProblem() {
    XCTAssertEqual(
      PilotFollowFailure.from(rejected(403, "Insufficient scope."), isPro: true),
      .message("Your sign-in can't make this change. Sign out and back in, then try again.")
    )
  }

  func testFeatureOffAndMissingPilot() {
    XCTAssertEqual(PilotFollowFailure.from(rejected(404, "Not Found"), isPro: true), .message("Following pilots isn't available right now."))
    XCTAssertEqual(PilotFollowFailure.from(rejected(404, nil), isPro: true), .message("Following pilots isn't available right now."))
    XCTAssertEqual(PilotFollowFailure.from(rejected(404, "Watchlist not found."), isPro: true), .message("Watchlist not found."))
  }

  func testServerReasonsAreShownFor400_409_422WithFallbacks() {
    XCTAssertEqual(PilotFollowFailure.from(rejected(409, "This pilot has no disclosures yet. Try again later."), isPro: true), .message("This pilot has no disclosures yet. Try again later."))
    XCTAssertEqual(PilotFollowFailure.from(rejected(409, nil), isPro: true), .message("No trades seen yet for this pilot. Try again later."))
    XCTAssertEqual(PilotFollowFailure.from(rejected(422, nil), isPro: true), .message("Choose an empty watchlist, or let Norviq create one."))
    XCTAssertEqual(PilotFollowFailure.from(rejected(400, nil), isPro: true), .message("Enter a starting amount between $1 and $10,000,000."))
  }

  func testOtherErrorsUseTheirDescription() {
    XCTAssertEqual(PilotFollowFailure.from(PilotsHTTPClient.Error.invalidStatus(500), isPro: true), .message("Request failed (500)."))
  }
}

@MainActor
final class PilotFormattingTests: XCTestCase {
  private let enUS = Locale(identifier: "en_US")

  func testDaysAreShownAsReportedInEveryTimeZone() {
    XCTAssertEqual(PilotFormatting.dayText("2026-09-14", locale: enUS), "Sep 14, 2026")
    XCTAssertEqual(PilotFormatting.dayText("not-a-day", locale: enUS), "not-a-day")
    XCTAssertNil(PilotFormatting.day("2026/09/14"))
  }

  func testValuePointsDropBadDatesAndSortOldestFirst() {
    let points = PilotFormatting.valuePoints([
      PilotFollowSnapshotResponse(date: "2026-10-02", value: 10_420, cash: 10),
      PilotFollowSnapshotResponse(date: "garbage", value: 1, cash: 0),
      PilotFollowSnapshotResponse(date: "2026-10-01", value: 10_000, cash: 10)
    ])
    XCTAssertEqual(points.map(\.value), [10_000, 10_420])
  }

  func testPerformanceAgainstStartingCapital() throws {
    let performance = try XCTUnwrap(PilotFormatting.performance(start: 10_000, latest: 10_420))
    XCTAssertEqual(performance, 0.042, accuracy: 1e-9)
    XCTAssertNil(PilotFormatting.performance(start: nil, latest: 10_420))
    XCTAssertNil(PilotFormatting.performance(start: 0, latest: 10_420))
    XCTAssertNil(PilotFormatting.performance(start: 10_000, latest: nil))
    XCTAssertEqual(PilotFormatting.signedPercent(0.042, locale: enUS), "+4.2%")
    XCTAssertEqual(PilotFormatting.signedPercent(-0.031, locale: enUS), "-3.1%")
  }

  func testPilotSubtitles() {
    XCTAssertEqual(PilotFormatting.subtitle(for: .fixture(holdingsCount: 12)), "Representative · 12 holdings")
    XCTAssertEqual(PilotFormatting.subtitle(for: .fixture(holdingsCount: 1)), "Representative · 1 holding")
    XCTAssertEqual(PilotFormatting.subtitle(for: .fixture(holdingsCount: 0)), "Representative · No trades seen yet")
    XCTAssertEqual(PilotFormatting.subtitle(for: .fixture(slug: "berkshire", displayName: "Berkshire", kind: .fund, holdingsCount: 40)), "13F fund · 40 holdings")
  }

  func testSkippedPutsNote() {
    XCTAssertNil(PilotFormatting.skippedPutsNote(0))
    XCTAssertEqual(PilotFormatting.skippedPutsNote(1), "1 put trade wasn't mirrored: a simulated portfolio can't go short.")
    XCTAssertEqual(PilotFormatting.skippedPutsNote(3), "3 put trades weren't mirrored: a simulated portfolio can't go short.")
  }

  func testDisclosureText() throws {
    let call = try XCTUnwrap(PilotDetail.fixture().recentDisclosures.first)
    XCTAssertEqual(PilotFormatting.disclosureTitle(call), "Bought NVDA calls")
    XCTAssertEqual(
      PilotFormatting.disclosureDetail(call, locale: enUS),
      "$1,001–$15,000 · traded Sep 14, 2026 · disclosed Sep 28, 2026"
    )
    let put = PilotDisclosureItem(symbol: "TSLA", side: "buy", instrument: "put", transactionDate: nil, disclosureDate: nil, amountMin: 50_000, amountMax: nil, period: nil)
    XCTAssertTrue(PilotFormatting.isSkippedPut(put))
    XCTAssertEqual(PilotFormatting.disclosureTitle(put), "Bought TSLA puts")
    XCTAssertEqual(PilotFormatting.disclosureDetail(put, locale: enUS), "Over $50,000")
    let fund = PilotDisclosureItem(symbol: "AAPL", side: "sell_full", instrument: "stock", transactionDate: nil, disclosureDate: nil, amountMin: nil, amountMax: nil, period: "2026Q2")
    XCTAssertEqual(PilotFormatting.disclosureTitle(fund), "Sold all AAPL")
    XCTAssertEqual(PilotFormatting.disclosureDetail(fund, locale: enUS), "13F period 2026Q2")
  }

  func testWeightAndMoney() {
    XCTAssertEqual(PilotFormatting.weight(0.2534, locale: enUS), "25.3%")
    XCTAssertEqual(PilotFormatting.money(10_000, currency: "USD", wholeUnits: true, locale: enUS), "$10,000")
  }

  func testFollowSubtitles() {
    XCTAssertEqual(PilotFormatting.followSubtitle(.fixture(), locale: enUS), "Simulated portfolio · started with $10,000")
    XCTAssertEqual(PilotFormatting.followSubtitle(.fixture(targetKind: .watchlist), locale: enUS), "Watchlist feed")
  }

  func testEventText() {
    XCTAssertEqual(PilotFormatting.eventTitle(.fixture(kind: "buy"), locale: enUS), "Bought 12.5 NVDA")
    XCTAssertEqual(PilotFormatting.eventTitle(.fixture(kind: "sell", quantity: 3), locale: enUS), "Sold 3 NVDA")
    XCTAssertEqual(PilotFormatting.eventTitle(.fixture(kind: "watch_added", quantity: nil), locale: enUS), "Added NVDA to the watchlist")
    XCTAssertEqual(PilotFormatting.eventTitle(.fixture(kind: "watch_exited", quantity: nil), locale: enUS), "Marked NVDA as exited")
    XCTAssertEqual(PilotFormatting.eventTitle(.fixture(kind: "skipped_unpriced"), locale: enUS), "Skipped NVDA: no price available")
    XCTAssertEqual(PilotFormatting.eventTitle(.fixture(kind: "skipped_limit"), locale: enUS), "Skipped NVDA: watchlist is full")
    XCTAssertEqual(PilotFormatting.eventTitle(.fixture(kind: "new_kind"), locale: enUS), "New Kind NVDA")
    XCTAssertEqual(
      PilotFormatting.eventDetail(.fixture(), currency: "USD", locale: enUS, timeZone: .gmt),
      "at $123.45 · Sep 30, 2026"
    )
    XCTAssertEqual(
      PilotFormatting.eventDetail(.fixture(kind: "watch_added", price: nil), currency: "USD", locale: enUS, timeZone: .gmt),
      "Sep 30, 2026"
    )
  }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots && xcodebuild test -project financeplan.xcodeproj -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:financeplanTests/PilotFollowRulesTests -only-testing:financeplanTests/PilotFollowFailureTests -only-testing:financeplanTests/PilotFormattingTests 2>&1 | tail -25`
Expected: build FAILS with `cannot find 'PilotFollowRules' in scope`.

- [ ] **Step 4: Write the rules**

Create `financeplan/Features/Pilots/PilotFollowRules.swift`:

```swift
import Foundation
import StockPlanShared

/// Client-side copy of the server's follow rules. Advisory only: the server
/// enforces every one of them and its answer wins.
enum PilotFollowRules {
  static let freeFollowLimit = 1
  static let proFollowLimit = 10
  static let maxStartingCapital: Double = 10_000_000

  enum Block: Equatable {
    /// No book yet (`holdingsCount == 0`); the server would answer 409.
    case noTradesYet
    /// Free and already at the one free follow.
    case needsPro
    /// Pro and at the follow limit.
    case atLimit
  }

  static func block(for pilot: PilotSummary, isPro: Bool, followCount: Int) -> Block? {
    if pilot.holdingsCount == 0 { return .noTradesYet }
    if isPro { return followCount >= proFollowLimit ? .atLimit : nil }
    return followCount >= freeFollowLimit ? .needsPro : nil
  }

  /// Nil when the amount is acceptable for a portfolio follow.
  static func capitalProblem(_ capital: Double?) -> String? {
    guard let capital else { return String(localized: "Enter a starting amount.") }
    guard capital > 0 else { return String(localized: "Enter an amount above zero.") }
    guard capital <= maxStartingCapital else { return String(localized: "The most you can start with is $10,000,000.") }
    return nil
  }
}

/// What the follow sheet does with a failed `POST /v1/pilot-follows`.
enum PilotFollowFailure: Equatable {
  /// Show the paywall.
  case needsPro
  /// Show this sentence inline.
  case message(String)

  static func from(_ error: any Error, isPro: Bool) -> PilotFollowFailure {
    guard case let .rejected(status, message)? = error as? PilotsHTTPClient.Error else {
      return .message(error.localizedDescription)
    }
    let reason = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    switch status {
    case 403:
      // The billing body reads "Upgrade required. feature=<feature> plan=<plan> …".
      if reason.localizedCaseInsensitiveContains("feature=portfolio_lists") {
        return .message(String(localized: "You've reached the portfolio limit for your plan. Archive a portfolio, then try again."))
      }
      if reason.localizedCaseInsensitiveContains("upgrade required") {
        return isPro
          ? .message(String(localized: "You're following 10 pilots, the most your plan allows. Stop following one to add another."))
          : .needsPro
      }
      return .message(String(localized: "Your sign-in can't make this change. Sign out and back in, then try again."))
    case 404:
      if reason.isEmpty || reason == "Not Found" {
        return .message(String(localized: "Following pilots isn't available right now."))
      }
      return .message(reason)
    case 400:
      return .message(reason.isEmpty ? String(localized: "Enter a starting amount between $1 and $10,000,000.") : reason)
    case 409:
      return .message(reason.isEmpty ? String(localized: "No trades seen yet for this pilot. Try again later.") : reason)
    case 422:
      return .message(reason.isEmpty ? String(localized: "Choose an empty watchlist, or let Norviq create one.") : reason)
    default:
      return .message(error.localizedDescription)
    }
  }
}
```

- [ ] **Step 5: Write the formatting**

Create `financeplan/Features/Pilots/PilotFormatting.swift`:

```swift
import Foundation
import StockPlanShared

struct PilotValuePoint: Identifiable, Equatable {
  let date: Date
  let value: Double
  var id: Date { date }
}

/// Display text for pilots. Pure, so the copy is pinned by tests. Functions
/// that format take a locale (and a time zone for instants) so tests do not
/// depend on the simulator's settings.
enum PilotFormatting {
  // MARK: - Dates

  private static let dayParser: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .gmt
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  /// Disclosure and snapshot days are UTC calendar days (`yyyy-MM-dd`).
  static func day(_ raw: String) -> Date? {
    dayParser.date(from: raw)
  }

  static func instant(_ raw: String) -> Date? {
    try? Date(raw, strategy: .iso8601)
  }

  /// A reported day such as "Sep 14, 2026". Formatted in UTC so it is never
  /// shown a day early west of Greenwich.
  static func dayText(_ raw: String, locale: Locale = .current) -> String {
    guard let date = day(raw) else { return raw }
    return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, timeZone: .gmt))
  }

  static func instantText(_ raw: String, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
    guard let date = instant(raw) else { return raw }
    return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, timeZone: timeZone))
  }

  // MARK: - Numbers

  static func weight(_ value: Double, locale: Locale = .current) -> String {
    value.formatted(.percent.precision(.fractionLength(1)).locale(locale))
  }

  static func money(_ value: Double, currency: String, wholeUnits: Bool = false, locale: Locale = .current) -> String {
    let style = FloatingPointFormatStyle<Double>.Currency(code: currency, locale: locale)
    return wholeUnits ? value.formatted(style.precision(.fractionLength(0))) : value.formatted(style)
  }

  static func signedPercent(_ fraction: Double, locale: Locale = .current) -> String {
    let magnitude = abs(fraction).formatted(.percent.precision(.fractionLength(1)).locale(locale))
    return fraction < 0 ? "-\(magnitude)" : "+\(magnitude)"
  }

  /// Latest simulated value against the starting capital, as a fraction.
  static func performance(start: Double?, latest: Double?) -> Double? {
    guard let start, start > 0, let latest else { return nil }
    return latest / start - 1
  }

  static func valuePoints(_ snapshots: [PilotFollowSnapshotResponse]) -> [PilotValuePoint] {
    snapshots
      .compactMap { snapshot in day(snapshot.date).map { PilotValuePoint(date: $0, value: snapshot.value) } }
      .sorted { $0.date < $1.date }
  }

  // MARK: - Pilots

  static func kindLabel(_ pilot: PilotSummary) -> String {
    switch pilot.kind {
    case .politician:
      switch pilot.chamber?.lowercased() {
      case "senate": return String(localized: "Senator")
      case "house": return String(localized: "Representative")
      default: return String(localized: "Member of Congress")
      }
    case .fund:
      return String(localized: "13F fund")
    }
  }

  static func subtitle(for pilot: PilotSummary) -> String {
    let holdings: String
    switch pilot.holdingsCount {
    case 0: holdings = String(localized: "No trades seen yet")
    case 1: holdings = String(localized: "1 holding")
    default: holdings = String(localized: "\(pilot.holdingsCount) holdings")
    }
    return "\(kindLabel(pilot)) · \(holdings)"
  }

  static func skippedPutsNote(_ count: Int) -> String? {
    switch count {
    case ...0: return nil
    case 1: return String(localized: "1 put trade wasn't mirrored: a simulated portfolio can't go short.")
    default: return String(localized: "\(count) put trades weren't mirrored: a simulated portfolio can't go short.")
    }
  }

  static func isSkippedPut(_ item: PilotDisclosureItem) -> Bool {
    item.instrument == "put"
  }

  static func disclosureTitle(_ item: PilotDisclosureItem) -> String {
    let verb: String
    switch item.side {
    case "buy": verb = String(localized: "Bought")
    case "sell": verb = String(localized: "Sold part of")
    case "sell_full": verb = String(localized: "Sold all")
    case "hold": verb = String(localized: "Holds")
    default: verb = item.side.replacingOccurrences(of: "_", with: " ").capitalized
    }
    switch item.instrument {
    case "call": return "\(verb) \(item.symbol) " + String(localized: "calls")
    case "put": return "\(verb) \(item.symbol) " + String(localized: "puts")
    default: return "\(verb) \(item.symbol)"
    }
  }

  static func amountRange(min: Double?, max: Double?, locale: Locale = .current) -> String? {
    let format = { (value: Double) in money(value, currency: "USD", wholeUnits: true, locale: locale) }
    if let min, let max {
      return max > min ? "\(format(min))–\(format(max))" : format(min)
    }
    if let min { return String(localized: "Over \(format(min))") }
    if let max { return String(localized: "Up to \(format(max))") }
    return nil
  }

  static func disclosureDetail(_ item: PilotDisclosureItem, locale: Locale = .current) -> String? {
    var parts: [String] = []
    if let amount = amountRange(min: item.amountMin, max: item.amountMax, locale: locale) { parts.append(amount) }
    if let traded = item.transactionDate { parts.append(String(localized: "traded \(dayText(traded, locale: locale))")) }
    if let disclosed = item.disclosureDate { parts.append(String(localized: "disclosed \(dayText(disclosed, locale: locale))")) }
    if let period = item.period { parts.append(String(localized: "13F period \(period)")) }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  // MARK: - Follows

  static func followSubtitle(_ follow: PilotFollowResponse, locale: Locale = .current) -> String {
    switch follow.targetKind {
    case .portfolio:
      guard let capital = follow.startingCapital else { return String(localized: "Simulated portfolio") }
      let amount = money(capital, currency: follow.currency, wholeUnits: true, locale: locale)
      return String(localized: "Simulated portfolio · started with \(amount)")
    case .watchlist:
      return String(localized: "Watchlist feed")
    }
  }

  static func eventTitle(_ event: PilotFollowEventResponse, locale: Locale = .current) -> String {
    let quantity = event.quantity.map { $0.formatted(.number.precision(.fractionLength(0...4)).locale(locale)) }
    switch event.kind {
    case "buy":
      return quantity.map { String(localized: "Bought \($0) \(event.symbol)") } ?? String(localized: "Bought \(event.symbol)")
    case "sell":
      return quantity.map { String(localized: "Sold \($0) \(event.symbol)") } ?? String(localized: "Sold \(event.symbol)")
    case "watch_added":
      return String(localized: "Added \(event.symbol) to the watchlist")
    case "watch_exited":
      return String(localized: "Marked \(event.symbol) as exited")
    case "skipped_unpriced":
      return String(localized: "Skipped \(event.symbol): no price available")
    case "skipped_limit":
      return String(localized: "Skipped \(event.symbol): watchlist is full")
    default:
      return "\(event.kind.replacingOccurrences(of: "_", with: " ").capitalized) \(event.symbol)"
    }
  }

  static func eventDetail(
    _ event: PilotFollowEventResponse,
    currency: String,
    locale: Locale = .current,
    timeZone: TimeZone = .current
  ) -> String {
    let day = instantText(event.pricedAt, locale: locale, timeZone: timeZone)
    guard let price = event.price else { return day }
    return String(localized: "at \(money(price, currency: currency, locale: locale)) · \(day)")
  }

  static func eventSymbolName(_ kind: String) -> String {
    switch kind {
    case "buy": return "plus.circle.fill"
    case "sell": return "minus.circle.fill"
    case "watch_added": return "eye"
    case "watch_exited": return "eye.slash"
    case "skipped_unpriced", "skipped_limit": return "exclamationmark.triangle"
    default: return "circle"
    }
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: the Step 3 command.
Expected: `** TEST SUCCEEDED **`. If only the en dash or `·` comparisons fail, the implementation uses a different character: keep `–` (U+2013) and `·` (U+00B7) in both files.

- [ ] **Step 7: Commit**

```bash
git add financeplan/Features/Pilots/PilotFollowRules.swift financeplan/Features/Pilots/PilotFormatting.swift financeplanTests/PilotsTestSupport.swift financeplanTests/PilotsLogicTests.swift
git commit -m "feat(pilots): follow rules, error mapping and display formatting"
```

---

### Task 4: PilotsStore (feature availability and follows)

**Files:**
- Create: `financeplan/Features/Pilots/PilotsStore.swift`
- Modify: `financeplan/API/Pilots/Container+PilotsFactories.swift` (add `pilotsStore`)
- Test: `financeplanTests/PilotsStoreTests.swift`

**Interfaces:**
- Consumes: `PilotsServicing`, `Container.pilotsService` (Task 2); `MockPilotsService`, fixtures (Task 3).
- Produces:
  - `@MainActor @Observable final class PilotsStore` with `init(service: any PilotsServicing = Container.shared.pilotsService())`.
    - `enum Availability: Equatable { case unknown, available, unavailable }`
    - `private(set) var availability: Availability`, `private(set) var pilots: [PilotSummary]`, `private(set) var follows: [PilotFollowResponse]`, `private(set) var followsRevision: Int`, `private(set) var isLoading: Bool`, `var errorMessage: String?`
    - `var isAvailable: Bool`
    - `func load() async`
    - `func insert(_ follow: PilotFollowResponse)`
    - `func replace(_ follow: PilotFollowResponse)`
    - `func remove(followId: String)`
    - `func follows(forPilot slug: String) -> [PilotFollowResponse]`
    - `static func isFeatureOff(_ error: any Error) -> Bool` (true for a 404)
  - `Container.pilotsStore: Factory<PilotsStore>` (singleton).

- [ ] **Step 1: Write the failing test**

Create `financeplanTests/PilotsStoreTests.swift`:

```swift
import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class PilotsStoreTests: XCTestCase {
  private let notFound = PilotsHTTPClient.Error.rejected(status: 404, message: "Not Found")

  func testLoadMarksTheFeatureAvailableAndKeepsFollows() async {
    let service = MockPilotsService()
    service.followsResult = .success([.fixture()])
    let store = PilotsStore(service: service)

    await store.load()

    XCTAssertEqual(store.availability, .available)
    XCTAssertTrue(store.isAvailable)
    XCTAssertEqual(store.pilots.map(\.slug), ["nancy-pelosi"])
    XCTAssertEqual(store.follows.map(\.id), ["11111111-1111-1111-1111-111111111111"])
    XCTAssertNil(store.errorMessage)
  }

  func testFeatureSwitchedOffHidesEverythingWithoutAnError() async {
    let service = MockPilotsService()
    service.followsResult = .success([.fixture()])
    let store = PilotsStore(service: service)
    await store.load()

    service.pilotsResult = .failure(notFound)
    service.followsResult = .failure(notFound)
    await store.load()

    XCTAssertEqual(store.availability, .unavailable)
    XCTAssertFalse(store.isAvailable)
    XCTAssertTrue(store.pilots.isEmpty)
    XCTAssertTrue(store.follows.isEmpty)
    XCTAssertNil(store.errorMessage)
  }

  func testOtherFailuresKeepEntryPointsHiddenUntilAFirstSuccess() async {
    let service = MockPilotsService()
    service.pilotsResult = .failure(PilotsHTTPClient.Error.invalidStatus(500))
    let store = PilotsStore(service: service)

    await store.load()

    XCTAssertEqual(store.availability, .unknown)
    XCTAssertFalse(store.isAvailable)
    XCTAssertEqual(store.errorMessage, "Request failed (500).")
  }

  func testInsertReplaceAndRemoveKeepOneCopyAndBumpTheRevision() {
    let store = PilotsStore(service: MockPilotsService())
    let follow = PilotFollowResponse.fixture()

    store.insert(follow)
    store.insert(follow)
    XCTAssertEqual(store.follows.count, 1)
    XCTAssertEqual(store.followsRevision, 2)

    store.replace(.fixture(status: .paused))
    XCTAssertEqual(store.follows.first?.status, .paused)
    XCTAssertEqual(store.followsRevision, 2)

    store.remove(followId: follow.id)
    XCTAssertTrue(store.follows.isEmpty)
    XCTAssertEqual(store.followsRevision, 3)
  }

  func testFollowsForPilotFiltersBySlug() {
    let store = PilotsStore(service: MockPilotsService())
    store.insert(.fixture(id: "a"))
    store.insert(.fixture(id: "b", pilot: .fixture(slug: "berkshire", displayName: "Berkshire", kind: .fund)))

    XCTAssertEqual(store.follows(forPilot: "nancy-pelosi").map(\.id), ["a"])
  }

  func testIsFeatureOffOnlyFor404() {
    XCTAssertTrue(PilotsStore.isFeatureOff(notFound))
    XCTAssertFalse(PilotsStore.isFeatureOff(PilotsHTTPClient.Error.rejected(status: 403, message: nil)))
    XCTAssertFalse(PilotsStore.isFeatureOff(URLError(.notConnectedToInternet)))
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots && xcodebuild test -project financeplan.xcodeproj -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:financeplanTests/PilotsStoreTests 2>&1 | tail -25`
Expected: build FAILS with `cannot find 'PilotsStore' in scope`.

- [ ] **Step 3: Write the store**

Create `financeplan/Features/Pilots/PilotsStore.swift`:

```swift
import Factory
import Foundation
import Observation
import StockPlanShared

/// Whether pilots are switched on, the pilot catalogue, and the viewer's
/// follows. One shared instance, so the workspace row, the portfolio banner
/// and the pilot screens agree the moment a follow starts or stops.
@MainActor
@Observable
final class PilotsStore {
  enum Availability: Equatable {
    /// Not loaded yet, or the last load failed for a reason other than 404.
    case unknown
    case available
    /// The server answered 404: `PILOTS_ENABLED` is off.
    case unavailable
  }

  private(set) var availability: Availability = .unknown
  private(set) var pilots: [PilotSummary] = []
  private(set) var follows: [PilotFollowResponse] = []
  /// Bumped when a follow is added or removed, so screens can reload what a
  /// follow creates (a new portfolio) with `.task(id:)`.
  private(set) var followsRevision = 0
  private(set) var isLoading = false
  var errorMessage: String?

  private let service: any PilotsServicing

  init(service: any PilotsServicing = Container.shared.pilotsService()) {
    self.service = service
  }

  var isAvailable: Bool { availability == .available }

  func load() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      async let pilots = service.pilots()
      async let follows = service.follows()
      (self.pilots, self.follows) = try await (pilots, follows)
      availability = .available
      errorMessage = nil
    } catch is CancellationError {
      return
    } catch {
      if Self.isFeatureOff(error) {
        availability = .unavailable
        pilots = []
        follows = []
        errorMessage = nil
      } else {
        errorMessage = error.localizedDescription
      }
    }
  }

  func insert(_ follow: PilotFollowResponse) {
    follows.removeAll { $0.id == follow.id }
    follows.insert(follow, at: 0)
    followsRevision += 1
  }

  func replace(_ follow: PilotFollowResponse) {
    guard let index = follows.firstIndex(where: { $0.id == follow.id }) else { return }
    follows[index] = follow
  }

  func remove(followId: String) {
    follows.removeAll { $0.id == followId }
    followsRevision += 1
  }

  func follows(forPilot slug: String) -> [PilotFollowResponse] {
    follows.filter { $0.pilot.slug == slug }
  }

  /// Every pilots route answers 404 while the feature flag is off.
  static func isFeatureOff(_ error: any Error) -> Bool {
    (error as? any HTTPClientError)?.statusCode == 404
  }
}
```

Replace `financeplan/API/Pilots/Container+PilotsFactories.swift` with:

```swift
import Factory
import Foundation

extension Container {
  var pilotsService: Factory<any PilotsServicing> {
    self { @MainActor in
      DefaultPilotsService(environmentManager: self.appEnvironment())
    }
  }

  /// Shared so the workspace row, the portfolio banner and the pilot screens
  /// see the same follows.
  var pilotsStore: Factory<PilotsStore> {
    self { @MainActor in PilotsStore() }.singleton
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: the Step 2 command.
Expected: `** TEST SUCCEEDED **`, 6 tests passed.

- [ ] **Step 5: Commit**

```bash
git add financeplan/Features/Pilots/PilotsStore.swift financeplan/API/Pilots/Container+PilotsFactories.swift financeplanTests/PilotsStoreTests.swift
git commit -m "feat(pilots): shared pilots store with feature-flag detection"
```

---

### Task 5: Pilot follow detail (event log, value chart, pause/resume, stop)

**Files:**
- Create: `financeplan/Features/Pilots/PilotFollowDetailModel.swift`
- Create: `financeplan/Features/Pilots/PilotFollowValueChart.swift`
- Create: `financeplan/Features/Pilots/PilotFollowDetailScreen.swift`
- Test: `financeplanTests/PilotFollowDetailModelTests.swift`

**Interfaces:**
- Consumes: `PilotsServicing` (Task 2); `PilotFormatting`, `PilotValuePoint` (Task 3); `PilotsStore.replace/remove/isFeatureOff`, `Container.pilotsStore` (Task 4); `boardsErrorBinding(_:)` (`Features/Boards/BoardsDirectoryScreen.swift`); `VigilPageHeader`, `.vigilListChrome()`, `.vigilNavigationTitle(_:)`, `.vigilInlineNavigationBar()`.
- Produces:
  - `@MainActor @Observable final class PilotFollowDetailModel` with `init(follow: PilotFollowResponse, service: any PilotsServicing = Container.shared.pilotsService(), store: PilotsStore = Container.shared.pilotsStore())`.
    - `private(set) var follow`, `events`, `valuePoints`, `isLoading`, `isSaving`; `var errorMessage: String?`
    - `var isPortfolio: Bool`, `var isPaused: Bool`, `var latestValue: Double?`, `var performance: Double?`
    - `func load() async`, `func setPaused(_ paused: Bool) async`, `func stop() async -> Bool`
  - `struct PilotFollowDetailScreen: View { init(follow: PilotFollowResponse) }`
  - `struct PilotFollowRow: View { let follow: PilotFollowResponse }` (used by Tasks 7 and 8)
  - `struct PilotFollowValueChart: View { let points: [PilotValuePoint]; let currency: String }`

- [ ] **Step 1: Write the failing test**

Create `financeplanTests/PilotFollowDetailModelTests.swift`:

```swift
import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class PilotFollowDetailModelTests: XCTestCase {
  private func makeModel(_ follow: PilotFollowResponse = .fixture(), service: MockPilotsService) -> (PilotFollowDetailModel, PilotsStore) {
    let store = PilotsStore(service: service)
    store.insert(follow)
    return (PilotFollowDetailModel(follow: follow, service: service, store: store), store)
  }

  func testPortfolioFollowLoadsEventsAndSortedValue() async throws {
    let service = MockPilotsService()
    service.eventsResult = .success([.fixture(id: "e2", kind: "sell"), .fixture(id: "e1")])
    service.snapshotsResult = .success([
      PilotFollowSnapshotResponse(date: "2026-10-02", value: 10_420, cash: 5),
      PilotFollowSnapshotResponse(date: "2026-10-01", value: 10_000, cash: 5)
    ])
    let (model, _) = makeModel(service: service)

    await model.load()

    XCTAssertEqual(model.events.map(\.id), ["e2", "e1"])
    XCTAssertEqual(model.valuePoints.map(\.value), [10_000, 10_420])
    XCTAssertEqual(model.latestValue, 10_420)
    XCTAssertEqual(try XCTUnwrap(model.performance), 0.042, accuracy: 1e-9)
    XCTAssertNil(model.errorMessage)
  }

  func testWatchlistFollowShowsTheFeedAndNeverAsksForSnapshots() async {
    let service = MockPilotsService()
    service.eventsResult = .success([.fixture(kind: "watch_added", quantity: nil, price: nil)])
    let (model, _) = makeModel(.fixture(targetKind: .watchlist), service: service)

    await model.load()

    XCTAssertFalse(model.isPortfolio)
    XCTAssertEqual(model.events.count, 1)
    XCTAssertTrue(model.valuePoints.isEmpty)
    XCTAssertNil(model.performance)
    XCTAssertEqual(service.snapshotCalls, 0)
  }

  func testPauseUpdatesTheFollowAndTheSharedStore() async {
    let service = MockPilotsService()
    let (model, store) = makeModel(service: service)

    await model.setPaused(true)

    XCTAssertEqual(service.statusRequests, [.paused])
    XCTAssertTrue(model.isPaused)
    XCTAssertEqual(store.follows.first?.status, .paused)

    await model.setPaused(false)
    XCTAssertEqual(service.statusRequests, [.paused, .active])
    XCTAssertFalse(model.isPaused)
  }

  func testStopRemovesTheFollowFromTheStore() async {
    let service = MockPilotsService()
    let (model, store) = makeModel(service: service)

    let stopped = await model.stop()

    XCTAssertTrue(stopped)
    XCTAssertEqual(service.stoppedFollowIds, ["11111111-1111-1111-1111-111111111111"])
    XCTAssertTrue(store.follows.isEmpty)
  }

  func testStoppingAFollowThatIsAlreadyGoneCountsAsStopped() async {
    let service = MockPilotsService()
    service.stopError = PilotsHTTPClient.Error.rejected(status: 404, message: "Follow not found.")
    let (model, store) = makeModel(service: service)

    let stopped = await model.stop()

    XCTAssertTrue(stopped)
    XCTAssertTrue(store.follows.isEmpty)
    XCTAssertNil(model.errorMessage)
  }

  func testStopFailureKeepsTheFollowAndSaysWhy() async {
    let service = MockPilotsService()
    service.stopError = PilotsHTTPClient.Error.invalidStatus(500)
    let (model, store) = makeModel(service: service)

    let stopped = await model.stop()

    XCTAssertFalse(stopped)
    XCTAssertEqual(store.follows.count, 1)
    XCTAssertEqual(model.errorMessage, "Request failed (500).")
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots && xcodebuild test -project financeplan.xcodeproj -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:financeplanTests/PilotFollowDetailModelTests 2>&1 | tail -25`
Expected: build FAILS with `cannot find 'PilotFollowDetailModel' in scope`.

- [ ] **Step 3: Write the model**

Create `financeplan/Features/Pilots/PilotFollowDetailModel.swift`:

```swift
import Factory
import Foundation
import Observation
import StockPlanShared

@MainActor
@Observable
final class PilotFollowDetailModel {
  private(set) var follow: PilotFollowResponse
  private(set) var events: [PilotFollowEventResponse] = []
  private(set) var valuePoints: [PilotValuePoint] = []
  private(set) var isLoading = false
  private(set) var isSaving = false
  var errorMessage: String?

  private let service: any PilotsServicing
  private let store: PilotsStore

  init(
    follow: PilotFollowResponse,
    service: any PilotsServicing = Container.shared.pilotsService(),
    store: PilotsStore = Container.shared.pilotsStore()
  ) {
    self.follow = follow
    self.service = service
    self.store = store
  }

  var isPortfolio: Bool { follow.targetKind == .portfolio }
  var isPaused: Bool { follow.status == .paused }
  var latestValue: Double? { valuePoints.last?.value }
  var performance: Double? { PilotFormatting.performance(start: follow.startingCapital, latest: latestValue) }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      if isPortfolio {
        async let events = service.events(followId: follow.id)
        async let snapshots = service.snapshots(followId: follow.id)
        let (loadedEvents, loadedSnapshots) = try await (events, snapshots)
        self.events = loadedEvents
        valuePoints = PilotFormatting.valuePoints(loadedSnapshots)
      } else {
        // Watchlist follows have no value history; their feed is the event log.
        events = try await service.events(followId: follow.id)
        valuePoints = []
      }
      errorMessage = nil
    } catch is CancellationError {
      return
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func setPaused(_ paused: Bool) async {
    guard !isSaving else { return }
    isSaving = true
    defer { isSaving = false }
    do {
      let updated = try await service.setStatus(paused ? .paused : .active, followId: follow.id)
      follow = updated
      store.replace(updated)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// True once the follow is gone, so the screen can pop. A 404 means it was
  /// already stopped elsewhere, or the feature was switched off.
  func stop() async -> Bool {
    guard !isSaving else { return false }
    isSaving = true
    defer { isSaving = false }
    do {
      try await service.stopFollowing(followId: follow.id)
    } catch let error where PilotsStore.isFeatureOff(error) {
      // Nothing left to stop.
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
    store.remove(followId: follow.id)
    errorMessage = nil
    return true
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: the Step 2 command.
Expected: `** TEST SUCCEEDED **`, 6 tests passed.

- [ ] **Step 5: Write the chart**

Create `financeplan/Features/Pilots/PilotFollowValueChart.swift`:

```swift
import Charts
import SwiftUI

/// Daily simulated value of a portfolio follow, oldest first.
struct PilotFollowValueChart: View {
  let points: [PilotValuePoint]
  let currency: String

  var body: some View {
    if points.count < 2 {
      ContentUnavailableView(
        "Chart starts after two days",
        systemImage: "chart.xyaxis.line",
        description: Text("Norviq records the simulated value once a day.")
      )
    } else {
      Chart(points) { point in
        LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
          .interpolationMethod(.monotone)
      }
      .chartYScale(domain: .automatic(includesZero: false))
      .chartYAxis {
        AxisMarks { value in
          AxisGridLine()
          AxisValueLabel {
            if let amount = value.as(Double.self) {
              Text(amount, format: .currency(code: currency).precision(.fractionLength(0)))
            }
          }
        }
      }
      .frame(height: 200)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Simulated value")
      .accessibilityValue(accessibilitySummary)
    }
  }

  private var accessibilitySummary: String {
    guard let first = points.first, let last = points.last else { return "" }
    let start = PilotFormatting.money(first.value, currency: currency)
    let end = PilotFormatting.money(last.value, currency: currency)
    return String(localized: "From \(start) to \(end)")
  }
}
```

- [ ] **Step 6: Write the screen**

Create `financeplan/Features/Pilots/PilotFollowDetailScreen.swift`:

```swift
import Factory
import StockPlanShared
import SwiftUI

/// One follow: what Norviq simulated for it, its value, and the controls to
/// pause, resume or stop it.
struct PilotFollowDetailScreen: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model: PilotFollowDetailModel
  @State private var isConfirmingStop = false

  init(follow: PilotFollowResponse) {
    _model = State(initialValue: PilotFollowDetailModel(follow: follow))
  }

  var body: some View {
    List {
      Section {
        VigilPageHeader(
          watch: .wealth,
          title: LocalizedStringKey(model.follow.pilot.displayName),
          subtitle: LocalizedStringKey(PilotFormatting.followSubtitle(model.follow))
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
      }

      Section {
        PilotFollowSummary(follow: model.follow, latestValue: model.latestValue, performance: model.performance)
      }

      if model.isPortfolio {
        Section("Simulated value") {
          PilotFollowValueChart(points: model.valuePoints, currency: model.follow.currency)
        }
      }

      PilotFollowEventsSection(
        events: model.events,
        isLoading: model.isLoading,
        isPortfolio: model.isPortfolio,
        isWaitingForFirstTrades: model.follow.appliedVersion == 0,
        currency: model.follow.currency
      )

      Section {
        if model.isPaused {
          Button("Resume following", systemImage: "play.fill") {
            Task { await model.setPaused(false) }
          }
          .disabled(model.isSaving)
        } else {
          Button("Pause following", systemImage: "pause.fill") {
            Task { await model.setPaused(true) }
          }
          .disabled(model.isSaving)
        }
        Button("Stop following", systemImage: "xmark.circle", role: .destructive) {
          isConfirmingStop = true
        }
        .disabled(model.isSaving)
        .accessibilityIdentifier("pilots.follow.stop")
      } footer: {
        if model.isPortfolio {
          Text("Stopping keeps the portfolio and its simulated trades. Norviq stops updating it.")
        } else {
          Text("Stopping keeps the watchlist. Norviq stops updating it.")
        }
      }
    }
    .vigilListChrome()
    .vigilNavigationTitle(model.follow.pilot.displayName)
    .vigilInlineNavigationBar()
    .task { await model.load() }
    .refreshable { await model.load() }
    .confirmationDialog(
      "Stop following \(model.follow.pilot.displayName)?",
      isPresented: $isConfirmingStop,
      titleVisibility: .visible
    ) {
      Button("Stop following", role: .destructive) { Task { await stop() } }
    }
    .alert("Something went wrong", isPresented: boardsErrorBinding($model.errorMessage)) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(model.errorMessage ?? "")
    }
  }

  private func stop() async {
    if await model.stop() {
      dismiss()
    }
  }
}

/// A follow in a list: pilot, target, paused state.
struct PilotFollowRow: View {
  let follow: PilotFollowResponse

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: follow.targetKind == .portfolio ? "flask" : "eye")
        .foregroundStyle(Color.orange)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 3) {
        Text(follow.pilot.displayName).font(.headline)
        Text(PilotFormatting.followSubtitle(follow)).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      if follow.status == .paused {
        Text("Paused").font(.caption2).foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

private struct PilotFollowSummary: View {
  let follow: PilotFollowResponse
  let latestValue: Double?
  let performance: Double?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let latestValue {
        Text(PilotFormatting.money(latestValue, currency: follow.currency))
          .font(.title.weight(.bold))
          .monospacedDigit()
      }
      if let performance {
        Text("\(PilotFormatting.signedPercent(performance)) since you started")
          .font(.subheadline)
          .foregroundStyle(performance < 0 ? Color.red : Color.green)
      }
      if follow.status == .paused {
        Label("Paused. Norviq isn't copying new disclosures.", systemImage: "pause.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Text("Simulated. No real money is invested.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

private struct PilotFollowEventsSection: View {
  let events: [PilotFollowEventResponse]
  let isLoading: Bool
  let isPortfolio: Bool
  let isWaitingForFirstTrades: Bool
  let currency: String

  var body: some View {
    Section {
      if events.isEmpty, !isLoading {
        if isWaitingForFirstTrades {
          Text("Norviq is placing the first simulated trades. Check back shortly.").foregroundStyle(.secondary)
        } else {
          Text("No changes yet.").foregroundStyle(.secondary)
        }
      }
      ForEach(events) { event in
        PilotFollowEventRow(event: event, currency: currency)
      }
    } header: {
      if isPortfolio {
        Text("Simulated trades")
      } else {
        Text("Watchlist feed")
      }
    } footer: {
      Text("Each trade is priced when Norviq sees the disclosure, not on the pilot's trade date.")
    }
  }
}

private struct PilotFollowEventRow: View {
  let event: PilotFollowEventResponse
  let currency: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: PilotFormatting.eventSymbolName(event.kind))
        .foregroundStyle(.secondary)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 3) {
        Text(PilotFormatting.eventTitle(event)).font(.subheadline.weight(.semibold))
        Text(PilotFormatting.eventDetail(event, currency: currency)).font(.caption).foregroundStyle(.secondary)
        if let note = event.note, !note.isEmpty {
          Text(note).font(.caption2).foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }
}
```

- [ ] **Step 7: Build**

Run: `cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots && make ios-build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add financeplan/Features/Pilots/PilotFollowDetailModel.swift financeplan/Features/Pilots/PilotFollowValueChart.swift financeplan/Features/Pilots/PilotFollowDetailScreen.swift financeplanTests/PilotFollowDetailModelTests.swift
git commit -m "feat(pilots): follow detail with event log, value chart, pause and stop"
```

---

### Task 6: Follow sheet (target, capital, disclaimer, paywall)

**Files:**
- Create: `financeplan/Features/Pilots/FollowPilotModel.swift`
- Create: `financeplan/Features/Pilots/FollowPilotSheet.swift`
- Test: `financeplanTests/FollowPilotModelTests.swift`

**Interfaces:**
- Consumes: `PilotsServicing.follow(_:idempotencyKey:)`, `.watchlists()` (Task 2); `PilotFollowRules.capitalProblem`, `PilotFollowFailure.from` (Task 3); `PilotsStore.insert` (Task 4); `MoneyInputParser.parse(_:)`; `FormErrorBanner(message:)`; `PaywallView(billingManager:)`; `Container.billingManager`.
- Produces:
  - `@MainActor @Observable final class FollowPilotModel` with `init(pilot: PilotSummary, isPro: Bool, idempotencyKey: String = UUID().uuidString, service: any PilotsServicing = Container.shared.pilotsService(), store: PilotsStore = Container.shared.pilotsStore())`.
    - `let pilot`, `let idempotencyKey`, `var target: PilotFollowTargetKind`, `var capitalText: String`, `var watchlistListId: String?`, `private(set) var watchlists`, `private(set) var isSubmitting`, `var failure: PilotFollowFailure?`
    - `var capital: Double?`, `var formProblem: String?`, `var failureMessage: String?`
    - `func requiresPro(isPro: Bool) -> Bool`, `func makeRequest() -> PilotFollowCreateRequest?`, `func loadWatchlists() async`, `func submit(isPro: Bool) async -> PilotFollowResponse?`
  - `struct FollowPilotSheet: View { init(pilot: PilotSummary, lagNote: String, isPro: Bool) }`

- [ ] **Step 1: Write the failing test**

Create `financeplanTests/FollowPilotModelTests.swift`:

```swift
import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class FollowPilotModelTests: XCTestCase {
  private func makeModel(isPro: Bool, service: MockPilotsService = MockPilotsService()) -> (FollowPilotModel, MockPilotsService, PilotsStore) {
    let store = PilotsStore(service: service)
    let model = FollowPilotModel(pilot: .fixture(), isPro: isPro, idempotencyKey: "sheet-key", service: service, store: store)
    return (model, service, store)
  }

  func testProStartsOnAPortfolioAndFreeOnAWatchlist() {
    XCTAssertEqual(makeModel(isPro: true).0.target, .portfolio)
    XCTAssertEqual(makeModel(isPro: false).0.target, .watchlist)
  }

  func testPortfolioRequestCarriesTheCapitalAndAsksForANewPortfolio() {
    let (model, _, _) = makeModel(isPro: true)
    model.capitalText = "25000"

    XCTAssertEqual(
      model.makeRequest(),
      PilotFollowCreateRequest(pilotSlug: "nancy-pelosi", targetKind: .portfolio, portfolioListId: nil, watchlistListId: nil, startingCapital: 25_000)
    )
  }

  func testWatchlistRequestCarriesTheChosenListAndNoCapital() {
    let (model, _, _) = makeModel(isPro: false)
    model.capitalText = "25000"
    XCTAssertEqual(
      model.makeRequest(),
      PilotFollowCreateRequest(pilotSlug: "nancy-pelosi", targetKind: .watchlist, portfolioListId: nil, watchlistListId: nil, startingCapital: nil)
    )

    model.watchlistListId = "33333333-3333-3333-3333-333333333333"
    XCTAssertEqual(model.makeRequest()?.watchlistListId, "33333333-3333-3333-3333-333333333333")
  }

  func testInvalidCapitalNeverReachesTheServer() async {
    let (model, service, _) = makeModel(isPro: true)
    for text in ["", "abc", "0", "20000000"] {
      model.capitalText = text
      let follow = await model.submit(isPro: true)
      XCTAssertNil(follow, text)
      XCTAssertNotNil(model.failureMessage, text)
    }
    XCTAssertTrue(service.followRequests.isEmpty)
  }

  func testFreeChoosingAPortfolioGetsThePaywallWithoutARequest() async {
    let (model, service, _) = makeModel(isPro: false)
    model.target = .portfolio
    model.capitalText = "10000"

    XCTAssertTrue(model.requiresPro(isPro: false))
    let follow = await model.submit(isPro: false)

    XCTAssertNil(follow)
    XCTAssertEqual(model.failure, .needsPro)
    XCTAssertTrue(service.followRequests.isEmpty)
  }

  func testFreeAtTheServerLimitGetsThePaywall() async {
    let service = MockPilotsService()
    service.followResult = .failure(PilotsHTTPClient.Error.rejected(status: 403, message: "Upgrade required. feature=pilot_follows plan=free limit=1 current=1"))
    let (model, _, _) = makeModel(isPro: false, service: service)

    _ = await model.submit(isPro: false)

    XCTAssertEqual(model.failure, .needsPro)
    XCTAssertNil(model.failureMessage)
  }

  func testNonEmptyWatchlistShowsTheServerReason() async {
    let service = MockPilotsService()
    service.followResult = .failure(PilotsHTTPClient.Error.rejected(status: 422, message: "Choose an empty watchlist, or let Norviq create one."))
    let (model, _, store) = makeModel(isPro: true, service: service)
    model.target = .watchlist
    model.watchlistListId = "33333333-3333-3333-3333-333333333333"

    let follow = await model.submit(isPro: true)

    XCTAssertNil(follow)
    XCTAssertEqual(model.failureMessage, "Choose an empty watchlist, or let Norviq create one.")
    XCTAssertTrue(store.follows.isEmpty)
  }

  func testEveryAttemptFromOneSheetReusesTheIdempotencyKey() async {
    let service = MockPilotsService()
    service.followResult = .failure(PilotsHTTPClient.Error.invalidStatus(502))
    let (model, _, _) = makeModel(isPro: true, service: service)

    _ = await model.submit(isPro: true)
    service.followResult = .success(.fixture())
    _ = await model.submit(isPro: true)

    XCTAssertEqual(service.idempotencyKeys, ["sheet-key", "sheet-key"])
  }

  func testSuccessAddsTheFollowToTheSharedStore() async {
    let (model, _, store) = makeModel(isPro: true)

    let follow = await model.submit(isPro: true)

    XCTAssertEqual(follow?.id, "11111111-1111-1111-1111-111111111111")
    XCTAssertEqual(store.follows.map(\.id), ["11111111-1111-1111-1111-111111111111"])
    XCTAssertEqual(store.followsRevision, 1)
    XCTAssertNil(model.failure)
  }

  func testWatchlistsLoadAndAFailureLeavesOnlyNewWatchlist() async {
    let service = MockPilotsService()
    service.watchlistsResult = .success([WatchlistListDTOResponse(id: "w1", name: "Ideas", isDefault: true, createdAt: nil, updatedAt: nil)])
    let (model, _, _) = makeModel(isPro: false, service: service)

    await model.loadWatchlists()
    XCTAssertEqual(model.watchlists.map(\.id), ["w1"])

    service.watchlistsResult = .failure(PilotsHTTPClient.Error.invalidStatus(500))
    await model.loadWatchlists()
    XCTAssertTrue(model.watchlists.isEmpty)
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots && xcodebuild test -project financeplan.xcodeproj -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:financeplanTests/FollowPilotModelTests 2>&1 | tail -25`
Expected: build FAILS with `cannot find 'FollowPilotModel' in scope`.

- [ ] **Step 3: Write the model**

Create `financeplan/Features/Pilots/FollowPilotModel.swift`:

```swift
import Factory
import Foundation
import Observation
import StockPlanShared

@MainActor
@Observable
final class FollowPilotModel {
  let pilot: PilotSummary
  /// One key per sheet. The backend replays a cached success for the same key,
  /// so a double tap or a retry after a dropped response creates one follow.
  let idempotencyKey: String
  var target: PilotFollowTargetKind
  var capitalText = "10000"
  /// Nil means "let Norviq create a new watchlist".
  var watchlistListId: String?
  private(set) var watchlists: [WatchlistListDTOResponse] = []
  private(set) var isSubmitting = false
  var failure: PilotFollowFailure?

  private let service: any PilotsServicing
  private let store: PilotsStore

  init(
    pilot: PilotSummary,
    isPro: Bool,
    idempotencyKey: String = UUID().uuidString,
    service: any PilotsServicing = Container.shared.pilotsService(),
    store: PilotsStore = Container.shared.pilotsStore()
  ) {
    self.pilot = pilot
    self.idempotencyKey = idempotencyKey
    self.target = isPro ? .portfolio : .watchlist
    self.service = service
    self.store = store
  }

  var capital: Double? { MoneyInputParser.parse(capitalText) }

  /// Why the form can't be sent yet, or nil.
  var formProblem: String? {
    target == .portfolio ? PilotFollowRules.capitalProblem(capital) : nil
  }

  var failureMessage: String? {
    if case let .message(text)? = failure { return text }
    return nil
  }

  /// Simulated portfolios are Pro; Free follows into a watchlist.
  func requiresPro(isPro: Bool) -> Bool {
    target == .portfolio && !isPro
  }

  func loadWatchlists() async {
    watchlists = (try? await service.watchlists()) ?? []
  }

  func makeRequest() -> PilotFollowCreateRequest? {
    switch target {
    case .portfolio:
      guard PilotFollowRules.capitalProblem(capital) == nil, let capital else { return nil }
      return PilotFollowCreateRequest(
        pilotSlug: pilot.slug, targetKind: .portfolio,
        portfolioListId: nil, watchlistListId: nil, startingCapital: capital
      )
    case .watchlist:
      return PilotFollowCreateRequest(
        pilotSlug: pilot.slug, targetKind: .watchlist,
        portfolioListId: nil, watchlistListId: watchlistListId, startingCapital: nil
      )
    }
  }

  /// The new follow, or nil with `failure` set.
  func submit(isPro: Bool) async -> PilotFollowResponse? {
    guard !isSubmitting else { return nil }
    if requiresPro(isPro: isPro) {
      failure = .needsPro
      return nil
    }
    guard let request = makeRequest() else {
      failure = formProblem.map(PilotFollowFailure.message)
      return nil
    }
    isSubmitting = true
    defer { isSubmitting = false }
    do {
      let follow = try await service.follow(request, idempotencyKey: idempotencyKey)
      store.insert(follow)
      failure = nil
      return follow
    } catch {
      failure = PilotFollowFailure.from(error, isPro: isPro)
      return nil
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: the Step 2 command.
Expected: `** TEST SUCCEEDED **`, 10 tests passed.

- [ ] **Step 5: Write the sheet**

Create `financeplan/Features/Pilots/FollowPilotSheet.swift`:

```swift
import Factory
import StockPlanShared
import SwiftUI

/// Where to mirror a pilot, with how much, and what "simulated" means here.
struct FollowPilotSheet: View {
  @Environment(\.dismiss) private var dismiss
  @InjectedObservable(\Container.billingManager) private var billingManager
  @State private var model: FollowPilotModel
  @State private var isPaywallPresented = false
  let lagNote: String

  init(pilot: PilotSummary, lagNote: String, isPro: Bool) {
    _model = State(initialValue: FollowPilotModel(pilot: pilot, isPro: isPro))
    self.lagNote = lagNote
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Mirror into", selection: $model.target) {
            Text("Simulated portfolio").tag(PilotFollowTargetKind.portfolio)
            Text("Watchlist").tag(PilotFollowTargetKind.watchlist)
          }
          .pickerStyle(.segmented)
          .accessibilityIdentifier("pilots.follow.target")
        }

        switch model.target {
        case .portfolio:
          FollowPortfolioTargetSection(model: model, isPro: billingManager.isPro)
        case .watchlist:
          FollowWatchlistTargetSection(model: model)
        }

        PilotFollowDisclaimer(lagNote: lagNote)

        if let message = model.failureMessage {
          Section { FormErrorBanner(message: message) }
        }
      }
      .navigationTitle("Follow \(model.pilot.displayName)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          if model.requiresPro(isPro: billingManager.isPro) {
            Button("Unlock Pro") { isPaywallPresented = true }
              .accessibilityIdentifier("pilots.follow.unlock")
          } else {
            Button("Follow") { Task { await follow() } }
              .disabled(model.isSubmitting || model.formProblem != nil)
              .accessibilityIdentifier("pilots.follow.submit")
          }
        }
      }
      .onChange(of: model.target) { model.failure = nil }
      .sheet(isPresented: $isPaywallPresented) {
        PaywallView(billingManager: billingManager)
      }
    }
  }

  private func follow() async {
    if await model.submit(isPro: billingManager.isPro) != nil {
      dismiss()
    } else if model.failure == .needsPro {
      isPaywallPresented = true
    }
  }
}

private struct FollowPortfolioTargetSection: View {
  @Bindable var model: FollowPilotModel
  let isPro: Bool

  var body: some View {
    Section {
      TextField("Starting amount (USD)", text: $model.capitalText)
        .keyboardType(.decimalPad)
        .accessibilityIdentifier("pilots.follow.capital")
      if let problem = model.formProblem, !model.capitalText.isEmpty {
        Text(problem).font(.footnote).foregroundStyle(.red)
      }
    } header: {
      Text("Starting amount")
    } footer: {
      if isPro {
        Text("Norviq creates a new simulated portfolio, puts this amount in as cash, and buys the pilot's current holdings at their weights. It rebalances on each new disclosure.")
      } else {
        Text("Simulated portfolios are part of Norviq Pro. Free accounts can follow one pilot into a watchlist.")
      }
    }
  }
}

private struct FollowWatchlistTargetSection: View {
  @Bindable var model: FollowPilotModel

  var body: some View {
    Section {
      Picker("Watchlist", selection: $model.watchlistListId) {
        Text("New watchlist").tag(String?.none)
        ForEach(model.watchlists) { list in
          Text(list.name).tag(Optional(list.id))
        }
      }
    } footer: {
      Text("Norviq adds each symbol the pilot buys and marks it exited when they sell. An existing watchlist must be empty.")
    }
    .task { await model.loadWatchlists() }
  }
}

private struct PilotFollowDisclaimer: View {
  let lagNote: String

  var body: some View {
    Section("Before you follow") {
      Label("This is a simulation. No real money is invested and no orders are placed.", systemImage: "flask")
      Label("Disclosures arrive late: up to 45 days for members of Congress and up to 135 days for 13F funds.", systemImage: "clock.arrow.circlepath")
      Label("Each trade is priced when Norviq sees the disclosure, not at the pilot's original price.", systemImage: "tag")
      if !lagNote.isEmpty {
        Text(lagNote).font(.footnote).foregroundStyle(.secondary)
      }
    }
  }
}
```

- [ ] **Step 6: Build**

Run: `cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots && make ios-build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add financeplan/Features/Pilots/FollowPilotModel.swift financeplan/Features/Pilots/FollowPilotSheet.swift financeplanTests/FollowPilotModelTests.swift
git commit -m "feat(pilots): follow sheet with target, capital, disclaimer and paywall"
```

---

### Task 7: Pilot detail and browse screens

**Files:**
- Create: `financeplan/Features/Pilots/PilotDetailModel.swift`
- Create: `financeplan/Features/Pilots/PilotDetailScreen.swift`
- Create: `financeplan/Features/Pilots/PilotsBrowseScreen.swift`
- Test: `financeplanTests/PilotDetailModelTests.swift`

**Interfaces:**
- Consumes: `PilotsServicing.pilot(slug:)` (Task 2); `PilotFollowRules.block`, `PilotFormatting` (Task 3); `PilotsStore` (Task 4); `PilotFollowDetailScreen`, `PilotFollowRow` (Task 5); `FollowPilotSheet` (Task 6); `PaywallView`; `Container.billingManager`.
- Produces:
  - `@MainActor @Observable final class PilotDetailModel` with `init(slug: String, service: any PilotsServicing = Container.shared.pilotsService())`, `private(set) var detail: PilotDetail?`, `private(set) var isLoading: Bool`, `var errorMessage: String?`, `func load() async`.
  - `struct PilotDetailScreen: View { init(pilot: PilotSummary) }`
  - `struct PilotsBrowseScreen: View { init() }` (used by Task 8)

- [ ] **Step 1: Write the failing test**

Create `financeplanTests/PilotDetailModelTests.swift`:

```swift
import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class PilotDetailModelTests: XCTestCase {
  func testLoadShowsWeightsDisclosuresAndLagNote() async {
    let service = MockPilotsService()
    service.detailResult = .success(.fixture(skippedPuts: 2))
    let model = PilotDetailModel(slug: "nancy-pelosi", service: service)

    await model.load()

    XCTAssertEqual(model.detail?.weights.map(\.symbol), ["NVDA", "AAPL"])
    XCTAssertEqual(model.detail?.skippedPuts, 2)
    XCTAssertEqual(model.detail?.lagNote, "Congressional trades are disclosed up to 45 days after they happen.")
    XCTAssertNil(model.errorMessage)
    XCTAssertFalse(model.isLoading)
  }

  func testMissingPilotOrFeatureOffShowsAPlainSentence() async {
    let service = MockPilotsService()
    service.detailResult = .failure(PilotsHTTPClient.Error.rejected(status: 404, message: "Not Found"))
    let model = PilotDetailModel(slug: "gone", service: service)

    await model.load()

    XCTAssertNil(model.detail)
    XCTAssertEqual(model.errorMessage, "This pilot isn't available right now.")
  }

  func testOtherFailuresShowTheirDescription() async {
    let service = MockPilotsService()
    service.detailResult = .failure(PilotsHTTPClient.Error.invalidStatus(500))
    let model = PilotDetailModel(slug: "nancy-pelosi", service: service)

    await model.load()

    XCTAssertEqual(model.errorMessage, "Request failed (500).")
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots && xcodebuild test -project financeplan.xcodeproj -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:financeplanTests/PilotDetailModelTests 2>&1 | tail -25`
Expected: build FAILS with `cannot find 'PilotDetailModel' in scope`.

- [ ] **Step 3: Write the model**

Create `financeplan/Features/Pilots/PilotDetailModel.swift`:

```swift
import Factory
import Foundation
import Observation
import StockPlanShared

@MainActor
@Observable
final class PilotDetailModel {
  let slug: String
  private(set) var detail: PilotDetail?
  private(set) var isLoading = false
  var errorMessage: String?

  private let service: any PilotsServicing

  init(slug: String, service: any PilotsServicing = Container.shared.pilotsService()) {
    self.slug = slug
    self.service = service
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      detail = try await service.pilot(slug: slug)
      errorMessage = nil
    } catch is CancellationError {
      return
    } catch {
      errorMessage = PilotsStore.isFeatureOff(error)
        ? String(localized: "This pilot isn't available right now.")
        : error.localizedDescription
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: the Step 2 command.
Expected: `** TEST SUCCEEDED **`, 3 tests passed.

- [ ] **Step 5: Write the pilot detail screen**

Create `financeplan/Features/Pilots/PilotDetailScreen.swift`:

```swift
import Factory
import StockPlanShared
import SwiftUI

/// One pilot: the book Norviq would mirror, recent disclosures, and the
/// reporting-lag note, with the Follow action.
struct PilotDetailScreen: View {
  @InjectedObservable(\Container.pilotsStore) private var store
  @InjectedObservable(\Container.billingManager) private var billingManager
  @State private var model: PilotDetailModel
  @State private var isFollowSheetPresented = false
  @State private var isPaywallPresented = false
  let pilot: PilotSummary

  init(pilot: PilotSummary) {
    self.pilot = pilot
    _model = State(initialValue: PilotDetailModel(slug: pilot.slug))
  }

  private var shownPilot: PilotSummary { model.detail?.pilot ?? pilot }

  private var block: PilotFollowRules.Block? {
    PilotFollowRules.block(for: shownPilot, isPro: billingManager.isPro, followCount: store.follows.count)
  }

  var body: some View {
    List {
      Section {
        VigilPageHeader(
          watch: .wealth,
          title: LocalizedStringKey(shownPilot.displayName),
          subtitle: LocalizedStringKey(PilotFormatting.subtitle(for: shownPilot))
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
      }

      if let detail = model.detail {
        Section {
          PilotFollowAction(
            block: block,
            onFollow: { isFollowSheetPresented = true },
            onUnlock: { isPaywallPresented = true }
          )
        }

        let following = store.follows(forPilot: pilot.slug)
        if !following.isEmpty {
          Section("You follow this pilot") {
            ForEach(following) { follow in
              NavigationLink {
                PilotFollowDetailScreen(follow: follow)
              } label: {
                PilotFollowRow(follow: follow)
              }
            }
          }
        }

        PilotWeightsSection(weights: detail.weights)
        PilotDisclosuresSection(items: detail.recentDisclosures, skippedPuts: detail.skippedPuts)

        Section("Reporting lag") {
          Text(detail.lagNote).font(.subheadline)
        }
      }
    }
    .overlay {
      if model.isLoading, model.detail == nil {
        ProgressView()
      }
    }
    .vigilListChrome()
    .vigilNavigationTitle(shownPilot.displayName)
    .vigilInlineNavigationBar()
    .task { await model.load() }
    .refreshable { await model.load() }
    .sheet(isPresented: $isFollowSheetPresented) {
      FollowPilotSheet(pilot: shownPilot, lagNote: model.detail?.lagNote ?? "", isPro: billingManager.isPro)
    }
    .sheet(isPresented: $isPaywallPresented) {
      PaywallView(billingManager: billingManager)
    }
    .alert("Something went wrong", isPresented: boardsErrorBinding($model.errorMessage)) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(model.errorMessage ?? "")
    }
  }
}

private struct PilotFollowAction: View {
  let block: PilotFollowRules.Block?
  let onFollow: () -> Void
  let onUnlock: () -> Void

  var body: some View {
    switch block {
    case nil:
      Button("Follow this pilot", systemImage: "person.crop.circle.badge.plus", action: onFollow)
        .accessibilityIdentifier("pilots.detail.follow")
    case .noTradesYet?:
      Label("No trades seen yet", systemImage: "hourglass")
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("pilots.detail.noTrades")
    case .needsPro?:
      Button("Follow more pilots with Pro", systemImage: "sparkles", action: onUnlock)
    case .atLimit?:
      Label(
        "You follow \(PilotFollowRules.proFollowLimit) pilots, the most a plan allows. Stop one to follow another.",
        systemImage: "exclamationmark.circle"
      )
      .foregroundStyle(.secondary)
    }
  }
}

private struct PilotWeightsSection: View {
  let weights: [PilotWeight]

  var body: some View {
    Section {
      if weights.isEmpty {
        Text("No trades seen yet").foregroundStyle(.secondary)
      }
      ForEach(weights, id: \.symbol) { weight in
        LabeledContent(weight.symbol, value: PilotFormatting.weight(weight.weight))
      }
    } header: {
      Text("Current weights")
    } footer: {
      Text("A simulated portfolio following this pilot holds these symbols at these weights.")
    }
  }
}

private struct PilotDisclosuresSection: View {
  let items: [PilotDisclosureItem]
  let skippedPuts: Int

  var body: some View {
    Section {
      if items.isEmpty {
        Text("No disclosures yet.").foregroundStyle(.secondary)
      }
      ForEach(Array(items.enumerated()), id: \.offset) { _, item in
        PilotDisclosureRow(item: item)
      }
    } header: {
      Text("Recent disclosures")
    } footer: {
      if let note = PilotFormatting.skippedPutsNote(skippedPuts) {
        Text(note)
      }
    }
  }
}

private struct PilotDisclosureRow: View {
  let item: PilotDisclosureItem

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(PilotFormatting.disclosureTitle(item)).font(.subheadline.weight(.semibold))
      if let detail = PilotFormatting.disclosureDetail(item) {
        Text(detail).font(.caption).foregroundStyle(.secondary)
      }
      if PilotFormatting.isSkippedPut(item) {
        Text("Not mirrored: copying a put would mean going short.")
          .font(.caption2)
          .foregroundStyle(.orange)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
```

- [ ] **Step 6: Write the browse screen**

Create `financeplan/Features/Pilots/PilotsBrowseScreen.swift`:

```swift
import Factory
import StockPlanShared
import SwiftUI

/// Pilots the viewer follows, then every politician and fund they can follow.
struct PilotsBrowseScreen: View {
  @InjectedObservable(\Container.pilotsStore) private var store

  var body: some View {
    List {
      Section {
        VigilPageHeader(
          watch: .wealth,
          title: "Pilots",
          subtitle: "Mirror a member of Congress or a 13F fund in a simulation. No real money moves."
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
      }

      if !store.follows.isEmpty {
        Section("Following") {
          ForEach(store.follows) { follow in
            NavigationLink {
              PilotFollowDetailScreen(follow: follow)
            } label: {
              PilotFollowRow(follow: follow)
            }
          }
        }
      }

      PilotListSection(title: "Politicians", pilots: store.pilots.filter { $0.kind == .politician })
      PilotListSection(title: "Funds", pilots: store.pilots.filter { $0.kind == .fund })
    }
    .overlay {
      if store.availability == .unavailable {
        ContentUnavailableView(
          "Pilots aren't available",
          systemImage: "person.2.slash",
          description: Text("Following pilots isn't switched on yet.")
        )
      } else if store.isLoading, store.pilots.isEmpty {
        ProgressView()
      }
    }
    .vigilListChrome()
    .vigilNavigationTitle("Pilots")
    .vigilInlineNavigationBar()
    .task { await store.load() }
    .refreshable { await store.load() }
    .alert("Something went wrong", isPresented: errorBinding) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(store.errorMessage ?? "")
    }
  }

  private var errorBinding: Binding<Bool> {
    Binding(
      get: { store.errorMessage != nil },
      set: { if !$0 { store.errorMessage = nil } }
    )
  }
}

private struct PilotListSection: View {
  let title: LocalizedStringKey
  let pilots: [PilotSummary]

  var body: some View {
    if !pilots.isEmpty {
      Section(title) {
        ForEach(pilots) { pilot in
          NavigationLink {
            PilotDetailScreen(pilot: pilot)
          } label: {
            PilotRow(pilot: pilot)
          }
          .accessibilityIdentifier("pilots.pilot.\(pilot.slug)")
        }
      }
    }
  }
}

private struct PilotRow: View {
  let pilot: PilotSummary

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: pilot.kind == .politician ? "building.columns" : "chart.pie")
        .foregroundStyle(Color.accentColor)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 3) {
        Text(pilot.displayName).font(.headline)
        Text(PilotFormatting.subtitle(for: pilot))
          .font(.caption)
          .foregroundStyle(pilot.holdingsCount == 0 ? Color.orange : Color.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
```

- [ ] **Step 7: Build**

Run: `cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots && make ios-build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`. If the compiler rejects the `let following = …` declaration inside the `List` builder, move it to a `private var following: [PilotFollowResponse] { store.follows(forPilot: pilot.slug) }` property and use `if !following.isEmpty`.

- [ ] **Step 8: Commit**

```bash
git add financeplan/Features/Pilots/PilotDetailModel.swift financeplan/Features/Pilots/PilotDetailScreen.swift financeplan/Features/Pilots/PilotsBrowseScreen.swift financeplanTests/PilotDetailModelTests.swift
git commit -m "feat(pilots): browse pilots and pilot detail with follow action"
```

---

### Task 8: Entry points (workspace row and portfolio banner)

**Files:**
- Create: `financeplan/Features/Pilots/PilotsEntryPoints.swift`
- Modify: `financeplan/Features/Pilots/PilotsStore.swift` (add `follow(forPortfolioId:)`)
- Modify: `financeplan/Features/PortfolioManagement/PortfolioWorkspaceScreen.swift:5-10, 30-31, 60-61`
- Modify: `financeplan/Features/PortfolioManagement/PortfolioDetailScreen.swift:4-11, 23-24`
- Test: `financeplanTests/PilotsStoreTests.swift` (append)

**Interfaces:**
- Consumes: `PilotsStore` (Task 4); `PilotFollowDetailScreen` (Task 5); `PilotsBrowseScreen` (Task 7).
- Produces:
  - `PilotsStore.follow(forPortfolioId portfolioId: String) -> PilotFollowResponse?` (case-insensitive UUID match)
  - `struct PilotsEntryRow: View { let followCount: Int }`
  - `struct PilotFollowBanner: View { let follow: PilotFollowResponse }`

- [ ] **Step 1: Write the failing test**

Append to `financeplanTests/PilotsStoreTests.swift`, inside `PilotsStoreTests`, before the final `}`:

```swift
  func testFollowForPortfolioMatchesTheListIdIgnoringCase() {
    let store = PilotsStore(service: MockPilotsService())
    store.insert(.fixture(id: "p", portfolioListId: "AAAAAAAA-0000-0000-0000-000000000001"))
    store.insert(.fixture(id: "w", targetKind: .watchlist))

    XCTAssertEqual(store.follow(forPortfolioId: "aaaaaaaa-0000-0000-0000-000000000001")?.id, "p")
    XCTAssertNil(store.follow(forPortfolioId: "33333333-3333-3333-3333-333333333333"))
    XCTAssertNil(store.follow(forPortfolioId: "BBBBBBBB-0000-0000-0000-000000000001"))
  }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots && xcodebuild test -project financeplan.xcodeproj -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:financeplanTests/PilotsStoreTests 2>&1 | tail -25`
Expected: build FAILS with `value of type 'PilotsStore' has no member 'follow'`.

- [ ] **Step 3: Add the lookup to the store**

In `financeplan/Features/Pilots/PilotsStore.swift`, add after `func follows(forPilot:)`:

```swift
  /// The follow that writes into this portfolio, if any. Compared without
  /// case: both sides are UUID strings and must not depend on their casing.
  func follow(forPortfolioId portfolioId: String) -> PilotFollowResponse? {
    follows.first { $0.portfolioListId?.caseInsensitiveCompare(portfolioId) == .orderedSame }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: the Step 2 command.
Expected: `** TEST SUCCEEDED **`, 7 tests passed.

- [ ] **Step 5: Write the entry-point views**

Create `financeplan/Features/Pilots/PilotsEntryPoints.swift`:

```swift
import StockPlanShared
import SwiftUI

/// The "Follow a pilot" row in the portfolio workspace.
struct PilotsEntryRow: View {
  let followCount: Int

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "person.2.wave.2")
        .foregroundStyle(Color.accentColor)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 3) {
        Text("Follow a pilot").font(.headline)
        if followCount == 0 {
          Text("Mirror a politician's or a fund's disclosed trades in a simulation")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text("Following ^[\(followCount) pilot](inflect: true)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }
}

/// Shown on a portfolio a pilot follow manages.
struct PilotFollowBanner: View {
  let follow: PilotFollowResponse

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Label("Following \(follow.pilot.displayName)", systemImage: "person.2.wave.2")
        .font(.headline)
      if follow.status == .paused {
        Text("Paused. Holdings stay as they are until you resume.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      } else {
        Text("Simulated. Trades mirror this pilot's disclosures, priced when Norviq sees them.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Text("You can't edit holdings by hand while you follow.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("portfolio.pilotFollowBanner")
  }
}
```

- [ ] **Step 6: Add the workspace row**

In `financeplan/Features/PortfolioManagement/PortfolioWorkspaceScreen.swift`:

(a) After line 6 (`@InjectedObservable(\.billingManager) private var billingManager`), add:

```swift
  @InjectedObservable(\Container.pilotsStore) private var pilots
```

(b) Between the closing `}` of the `if !billingManager.isPro { … }` block (line 30) and `Section("Portfolios") {` (line 32), insert:

```swift
      if pilots.isAvailable {
        Section {
          NavigationLink {
            PilotsBrowseScreen()
          } label: {
            PilotsEntryRow(followCount: pilots.follows.count)
          }
          .accessibilityIdentifier("portfolios.followPilot")
        }
      }
```

(c) Replace lines 60-61:

```swift
    .task { await model.load() }
    .refreshable { await model.load() }
```

with:

```swift
    // Re-runs when a follow starts or stops: a portfolio follow creates a portfolio.
    .task(id: pilots.followsRevision) { await model.load() }
    .task { await pilots.load() }
    .refreshable {
      await model.load()
      await pilots.load()
    }
```

- [ ] **Step 7: Add the portfolio banner**

In `financeplan/Features/PortfolioManagement/PortfolioDetailScreen.swift`:

(a) Add `import Factory` above `import StockPlanShared` (line 1).

(b) After `let model: PortfolioWorkspaceViewModel` (line 6), add:

```swift
  @InjectedObservable(\Container.pilotsStore) private var pilots
```

(c) Between the closing `}` of the header `Section { VigilPageHeader … }` (line 23) and `Section("Details") {` (line 25), insert:

```swift
      if let follow = pilots.follow(forPortfolioId: portfolio.id) {
        Section {
          NavigationLink {
            PilotFollowDetailScreen(follow: follow)
          } label: {
            PilotFollowBanner(follow: follow)
          }
        }
      }
```

- [ ] **Step 8: Build and run the pilots tests**

Run:
```bash
cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots
make ios-build 2>&1 | tail -5
xcodebuild test -project financeplan.xcodeproj -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:financeplanTests/PilotsStoreTests -only-testing:financeplanTests/PilotFollowDetailModelTests -only-testing:financeplanTests/FollowPilotModelTests -only-testing:financeplanTests/PilotDetailModelTests 2>&1 | tail -25
```
Expected: `** BUILD SUCCEEDED **`, then `** TEST SUCCEEDED **`.

- [ ] **Step 9: Commit**

```bash
git add financeplan/Features/Pilots/PilotsEntryPoints.swift financeplan/Features/Pilots/PilotsStore.swift financeplan/Features/PortfolioManagement/PortfolioWorkspaceScreen.swift financeplan/Features/PortfolioManagement/PortfolioDetailScreen.swift financeplanTests/PilotsStoreTests.swift
git commit -m "feat(pilots): follow-a-pilot row and following banner on portfolios"
```

---

### Task 9: Managed-portfolio 409 reaches the holdings UI verbatim

**Files:**
- Test: `financeplanTests/PilotManagedPortfolioErrorTests.swift` (create)
- Test: `financeplanTests/PortfolioViewModelTests.swift` (add one test after `testDeleteFailurePublishesError`, which ends at line 250)

**Interfaces:**
- Consumes: `StockHTTPClient(baseURL:session:authTokenProvider:)`, `StockHTTPClient.callWithoutResponse(_:)`, `DeleteStockEndpoint(stockId:)`, `StockHTTPClient.Error.api(String)`, `PortfolioViewModel.delete(id:)`, and the private `MockStockService` / `MarketDataServiceStub` already in `PortfolioViewModelTests.swift`.
- Produces: regression tests only. No production code changes, because the path already works (see Codebase facts). If a test fails, fix the path it names, not the test.

- [ ] **Step 1: Write the tests**

Create `financeplanTests/PilotManagedPortfolioErrorTests.swift`:

```swift
import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

private final class ManagedPortfolioURLProtocol: URLProtocol {
  nonisolated(unsafe) static var response: (Int, String) = (200, "{}")

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url,
          let response = HTTPURLResponse(url: url, statusCode: Self.response.0, httpVersion: nil, headerFields: ["Content-Type": "application/json"])
    else { fatalError("Could not build response") }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(Self.response.1.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

/// Hand edits to a portfolio a pilot follow manages are refused with 409. The
/// holdings screens show `errorDescription`, so the server's sentence must
/// survive the stock client unchanged.
@MainActor
final class PilotManagedPortfolioErrorTests: XCTestCase {
  static let reason = "This portfolio is managed by a pilot follow. Stop following to edit it."

  func testStockClientKeepsTheManagedPortfolioReason() async {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [ManagedPortfolioURLProtocol.self]
    ManagedPortfolioURLProtocol.response = (409, #"{"error":true,"code":"conflict","reason":"\#(Self.reason)"}"#)
    let client = StockHTTPClient(baseURL: URL(string: "https://api.example.com")!, session: URLSession(configuration: config))

    do {
      try await client.callWithoutResponse(DeleteStockEndpoint(stockId: "s1"))
      XCTFail("Expected a 409")
    } catch {
      XCTAssertEqual((error as? LocalizedError)?.errorDescription, Self.reason)
    }
  }
}
```

In `financeplanTests/PortfolioViewModelTests.swift`, insert after `testDeleteFailurePublishesError` (after line 250):

```swift
  func testDeleteInAPilotManagedPortfolioShowsTheServerReason() async {
    let service = MockStockService()
    let reason = "This portfolio is managed by a pilot follow. Stop following to edit it."
    service.deleteResult = .failure(StockHTTPClient.Error.api(reason))

    let viewModel = PortfolioViewModel(service: service, marketDataService: MarketDataServiceStub())
    let ok = await viewModel.delete(id: "nvda")

    XCTAssertFalse(ok)
    XCTAssertEqual(viewModel.errorMessage, reason)
  }
```

- [ ] **Step 2: Run the tests**

Run: `cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots && xcodebuild test -project financeplan.xcodeproj -scheme financeplan -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:financeplanTests/PilotManagedPortfolioErrorTests -only-testing:financeplanTests/PortfolioViewModelTests/testDeleteInAPilotManagedPortfolioShowsTheServerReason 2>&1 | tail -25`
Expected: `** TEST SUCCEEDED **`. These pin existing behavior, so they pass on first run. If `testStockClientKeepsTheManagedPortfolioReason` fails with "Request failed (409).", `APIErrorDecoding` no longer reads `reason`. Fix `financeplan/API/Support/APIErrorDecoding.swift`, not the test.

- [ ] **Step 3: Commit**

```bash
git add financeplanTests/PilotManagedPortfolioErrorTests.swift financeplanTests/PortfolioViewModelTests.swift
git commit -m "test(pilots): managed-portfolio 409 reaches holdings UI verbatim"
```

---

## Final verification (after Task 9)

- [ ] `cd /Users/fernandocorreiachill/Work/production/apps/norviq/norviq-ios-pilots && make ios-test 2>&1 | tail -30` → `** TEST SUCCEEDED **`.
- [ ] `grep -rniE 'auto.?pilot' financeplan financeplanTests docs` → no output.
- [ ] `git log --oneline main..HEAD` → one commit per task (9 or more), nothing pushed.
- [ ] Manual check in the simulator against staging with `PILOTS_ENABLED` on (switch environments with the app's environment picker):
  1. Portfolios → "Follow a pilot" row is visible. Pilots lists politicians and funds, and a pilot with no book reads "No trades seen yet" in orange.
  2. On a Pro account, follow a politician into a simulated portfolio with $10,000. The sheet shows the three disclaimer lines and the pilot's lag note. After Follow, the sheet closes, "You follow this pilot" appears, and the workspace lists a new "<pilot> copy" hypothetical portfolio.
  3. Open that portfolio from the workspace. The "Following <pilot>" banner shows, and tapping it opens the follow detail with trades and a value chart (or the "Chart starts after two days" state).
  4. In the main Portfolio tab, try to delete a holding of that portfolio. The toast or alert reads "This portfolio is managed by a pilot follow. Stop following to edit it."
  5. Pause, then Resume, then Stop following. The banner disappears and the portfolio stays.
  6. On a Free account, the sheet starts on Watchlist, and choosing "Simulated portfolio" turns the button into "Unlock Pro", which opens the paywall. A second follow attempt opens the paywall.
  7. With `PILOTS_ENABLED` off on staging, the "Follow a pilot" row and all banners are gone, and no error alert appears.
