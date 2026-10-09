import Foundation
import StockPlanShared
@testable import financeplan

final class MockTerminalPositionsService: TerminalPositionsServicing, @unchecked Sendable {
  var listResult: Result<TerminalPositionsListResponse, Error> = .success(.fixture())
  var createResult: Result<TerminalPositionResponse, Error> = .success(.fixture(id: "created"))
  /// Suspends `create` once so a second concurrent call can start.
  var createYields = false
  var updateResult: Result<TerminalPositionResponse, Error> = .success(.fixture())
  var deleteError: Error?
  var duplicateResult: Result<TerminalPositionResponse, Error> = .success(.fixture(id: "copy"))
  var reorderError: Error?
  /// Fails every reorder after this many have been recorded.
  var reorderFailsAfter: Int?
  var summaryResult: Result<TerminalPositionsSummaryResponse, Error> = .success(.fixture())
  var autobuysResult: Result<AutobuysListResponse, Error> = .success(.fixture())
  var createAutobuyResult: Result<AutobuyResponse, Error> = .success(.fixture(id: "new-autobuy"))
  var updateAutobuyResult: Result<AutobuyResponse, Error> = .success(.fixture())
  var deleteAutobuyError: Error?
  var shareFactsResult: Result<ShareFactsSuggestion, Error> = .success(.fixture())
  var scenarioResult: Result<TerminalScenarioSuggestion, Error> = .success(.fixture())

  private(set) var listTickers: [String?] = []
  private(set) var createRequests: [TerminalPositionCreateRequest] = []
  private(set) var updateIds: [String] = []
  private(set) var updateRequests: [TerminalPositionUpdateRequest] = []
  private(set) var deletedIds: [String] = []
  private(set) var duplicatedIds: [String] = []
  private(set) var reorderedIds: [[String]] = []
  private(set) var summaryCalls = 0
  private(set) var autobuysCalls = 0
  private(set) var createAutobuyRequests: [AutobuyCreateRequest] = []
  private(set) var updateAutobuyIds: [String] = []
  private(set) var updateAutobuyRequests: [AutobuyUpdateRequest] = []
  private(set) var deletedAutobuyIds: [String] = []
  private(set) var shareFactsTickers: [String] = []
  private(set) var scenarioTickers: [String] = []

  func list(ticker: String?) async throws -> TerminalPositionsListResponse {
    listTickers.append(ticker)
    return try listResult.get()
  }

  func create(_ request: TerminalPositionCreateRequest) async throws -> TerminalPositionResponse {
    createRequests.append(request)
    if createYields { await Task.yield() }
    return try createResult.get()
  }

  func update(id: String, _ request: TerminalPositionUpdateRequest) async throws -> TerminalPositionResponse {
    updateIds.append(id)
    updateRequests.append(request)
    return try updateResult.get()
  }

  func delete(id: String) async throws {
    if let deleteError { throw deleteError }
    deletedIds.append(id)
  }

  func duplicate(id: String) async throws -> TerminalPositionResponse {
    duplicatedIds.append(id)
    return try duplicateResult.get()
  }

  /// Echoes the rows from `listResult` in the order asked for.
  func reorder(ids: [String]) async throws -> TerminalPositionsListResponse {
    reorderedIds.append(ids)
    if let reorderError { throw reorderError }
    if let limit = reorderFailsAfter, reorderedIds.count > limit {
      throw TerminalPositionsHTTPClient.Error.invalidStatus(500)
    }
    let known = (try? listResult.get())?.positions ?? []
    return TerminalPositionsListResponse(
      currency: "USD",
      positions: ids.compactMap { id in known.first { $0.id == id } }
    )
  }

  func summary() async throws -> TerminalPositionsSummaryResponse {
    summaryCalls += 1
    return try summaryResult.get()
  }

  func autobuys() async throws -> AutobuysListResponse {
    autobuysCalls += 1
    return try autobuysResult.get()
  }

  func createAutobuy(_ request: AutobuyCreateRequest) async throws -> AutobuyResponse {
    createAutobuyRequests.append(request)
    return try createAutobuyResult.get()
  }

  func updateAutobuy(id: String, _ request: AutobuyUpdateRequest) async throws -> AutobuyResponse {
    updateAutobuyIds.append(id)
    updateAutobuyRequests.append(request)
    return try updateAutobuyResult.get()
  }

  func deleteAutobuy(id: String) async throws {
    if let deleteAutobuyError { throw deleteAutobuyError }
    deletedAutobuyIds.append(id)
  }

  func shareFacts(ticker: String) async throws -> ShareFactsSuggestion {
    shareFactsTickers.append(ticker)
    return try shareFactsResult.get()
  }

  func suggestScenario(ticker: String, horizonYears: Int?) async throws -> TerminalScenarioSuggestion {
    scenarioTickers.append(ticker)
    return try scenarioResult.get()
  }
}

extension TerminalPositionResponse {
  /// Derived fields come from the shared maths, exactly as the backend fills them.
  static func fixture(
    id: String = "p1",
    ticker: String = "AMZN",
    terminalShareCount: Double = 11_000_000_000,
    terminalMarketCap: Double = 10_000_000_000_000,
    valueWanted: Double = 1_000_000,
    sharesOwned: Double = 0,
    currentSharePrice: Double? = nil,
    sharesOutstanding: Double? = nil,
    notes: String? = nil,
    sortOrder: Int = 0
  ) -> TerminalPositionResponse {
    let outcome = TerminalMath.evaluate(TerminalScenarioInput(
      terminalShareCount: terminalShareCount,
      terminalMarketCap: terminalMarketCap,
      valueWanted: valueWanted,
      sharesOwned: sharesOwned,
      currentSharePrice: currentSharePrice
    ))
    var result: TerminalScenarioResult?
    var scenarioError: String?
    switch outcome {
    case let .success(value): result = value
    case let .failure(error): scenarioError = error.rawValue
    }
    return TerminalPositionResponse(
      id: id, ticker: ticker, sharesOutstanding: sharesOutstanding,
      terminalShareCount: terminalShareCount, terminalMarketCap: terminalMarketCap,
      valueWanted: valueWanted, sharesOwned: sharesOwned, currentSharePrice: currentSharePrice,
      notes: notes, sortOrder: sortOrder,
      terminalSharePrice: result?.terminalSharePrice, sharesNeeded: result?.sharesNeeded,
      capitalAtTodayPrice: result?.capitalAtTodayPrice, progress: result?.progress,
      sharesStillNeeded: result?.sharesStillNeeded, gapValueAtTerminal: result?.gapValueAtTerminal,
      scenarioError: scenarioError,
      createdAt: "2026-10-09T10:00:00Z", updatedAt: "2026-10-09T10:00:00Z"
    )
  }
}

extension TerminalPositionsListResponse {
  static func fixture(_ positions: [TerminalPositionResponse] = [.fixture()], currency: String = "USD") -> TerminalPositionsListResponse {
    TerminalPositionsListResponse(currency: currency, positions: positions)
  }
}

extension AutobuyResponse {
  static func fixture(
    id: String = "a1",
    ticker: String? = nil,
    label: String = "401k",
    amount: Double = 5_000,
    cadence: AutobuyCadence = .percentOfContribution,
    percent: Double? = 0.04,
    active: Bool = true
  ) -> AutobuyResponse {
    AutobuyResponse(
      id: id, ticker: ticker, label: label, amount: amount, cadence: cadence, percent: percent, active: active,
      monthlyEquivalent: AutobuyMath.monthlyEquivalent(amount: amount, cadence: cadence, percent: percent),
      createdAt: "2026-10-09T10:00:00Z", updatedAt: "2026-10-09T10:00:00Z"
    )
  }
}

extension AutobuysListResponse {
  static func fixture(_ autobuys: [AutobuyResponse] = [], currency: String = "USD") -> AutobuysListResponse {
    AutobuysListResponse(
      currency: currency,
      autobuys: autobuys,
      monthlyTotal: AutobuyMath.monthlyTotal(
        autobuys.map { (amount: $0.amount, cadence: $0.cadence, percent: $0.percent, active: $0.active) }
      )
    )
  }
}

extension TerminalPositionsSummaryResponse {
  static func fixture(
    _ positions: [TerminalPositionResponse] = [.fixture()],
    monthlyAutobuyTotal: Double = 0,
    currency: String = "USD"
  ) -> TerminalPositionsSummaryResponse {
    let valid = positions.filter { $0.scenarioError == nil }
    let priced = valid.compactMap(\.capitalAtTodayPrice)
    return TerminalPositionsSummaryResponse(
      currency: currency,
      positionCount: positions.count,
      totalValueWanted: valid.reduce(0) { $0 + $1.valueWanted },
      totalGapValueAtTerminal: valid.reduce(0) { $0 + ($1.gapValueAtTerminal ?? 0) },
      totalCapitalAtTodayPrice: priced.isEmpty ? nil : priced.reduce(0, +),
      pricedPositionCount: priced.count,
      monthlyAutobuyTotal: monthlyAutobuyTotal,
      topPositions: Array(valid.sorted { $0.valueWanted > $1.valueWanted }.prefix(3))
    )
  }
}

extension ShareFactsSuggestion {
  static func fixture(currency: String? = "USD") -> ShareFactsSuggestion {
    ShareFactsSuggestion(
      ticker: "AMZN", sharesOutstanding: 10_600_000_000, currentSharePrice: 220.5,
      currency: currency, asOf: "2026-10-08", sources: ["https://example.com/amzn-10q"]
    )
  }
}

extension TerminalScenarioSuggestion {
  static func fixture() -> TerminalScenarioSuggestion {
    TerminalScenarioSuggestion(
      ticker: "AMZN", terminalShareCount: 12_000_000_000, terminalMarketCap: 8_000_000_000_000,
      horizonYears: 10, rationale: "Cloud and ads keep compounding.", sources: ["https://example.com/amzn-outlook"]
    )
  }
}
