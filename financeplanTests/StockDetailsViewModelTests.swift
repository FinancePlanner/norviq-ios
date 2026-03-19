import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class StockDetailsViewModelTests: XCTestCase {
  private final class StockServiceMock: StockServicing {
    var createValuationCalls = 0
    var updateValuationCalls = 0
    var lastCreateValuationSymbol: String?
    var lastCreateValuationBearLow: Double?
    var lastCreateValuationBearHigh: Double?
    var lastCreateValuationBaseLow: Double?
    var lastCreateValuationBaseHigh: Double?
    var lastCreateValuationBullLow: Double?
    var lastCreateValuationBullHigh: Double?
    var lastCreateValuationRationale: String?
    var lastCreateValuationTargetDate: String?
    var lastUpdateValuationSymbol: String?
    var lastUpdateValuationBearLow: Double?
    var lastUpdateValuationBearHigh: Double?
    var lastUpdateValuationBaseLow: Double?
    var lastUpdateValuationBaseHigh: Double?
    var lastUpdateValuationBullLow: Double?
    var lastUpdateValuationBullHigh: Double?
    var lastUpdateValuationRationale: String?
    var lastUpdateValuationTargetDate: String?

    var createValuationResult: Result<StockValuationRequest, Error> = .failure(MockError.notConfigured)
    var updateValuationResult: Result<StockValuationRequest, Error> = .failure(MockError.notConfigured)

    func create(stock _: StockRequest) async throws -> StockResponse {
      throw MockError.notConfigured
    }

    func bulkCreate(stocks _: [StockRequest]) async throws -> BulkCreateStocksResponse {
      throw MockError.notConfigured
    }

    func fetchPortfolio() async throws -> [StockResponse] {
      throw MockError.notConfigured
    }

    func fetchStockDetails(stockId _: String) async throws -> StockDetails {
      throw MockError.notConfigured
    }

    func fetchStockHistory(symbol _: String) async throws -> [StockHistory] {
      throw MockError.notConfigured
    }

    func fetchStockNews(symbol _: String) async throws -> [StockNews] {
      throw MockError.notConfigured
    }

    func updateStock(_: StockResponse) async throws -> StockResponse {
      throw MockError.notConfigured
    }

    func delete(id _: String) async throws {}

    func getValuation(symbol _: String) async throws -> StockValuationRequest {
      throw MockError.notConfigured
    }

    func createValuation(
      symbol: String,
      draft: StockValuationDraft
    ) async throws -> StockValuationRequest {
      try await createValuation(
        symbol: symbol,
        bearLow: draft.bearLow,
        bearHigh: draft.bearHigh,
        baseLow: draft.baseLow,
        baseHigh: draft.baseHigh,
        bullLow: draft.bullLow,
        bullHigh: draft.bullHigh,
        rationale: draft.rationale,
        targetDate: draft.targetDate
      )
    }

    func createValuation(
      symbol: String,
      bearLow: Double,
      bearHigh: Double,
      baseLow: Double,
      baseHigh: Double,
      bullLow: Double,
      bullHigh: Double,
      rationale: String?,
      targetDate: String?
    ) async throws -> StockValuationRequest {
      createValuationCalls += 1
      lastCreateValuationSymbol = symbol
      lastCreateValuationBearLow = bearLow
      lastCreateValuationBearHigh = bearHigh
      lastCreateValuationBaseLow = baseLow
      lastCreateValuationBaseHigh = baseHigh
      lastCreateValuationBullLow = bullLow
      lastCreateValuationBullHigh = bullHigh
      lastCreateValuationRationale = rationale
      lastCreateValuationTargetDate = targetDate
      return try createValuationResult.get()
    }

    func updateValuation(
      symbol: String,
      draft: StockValuationDraft
    ) async throws -> StockValuationRequest {
      try await updateValuation(
        symbol: symbol,
        bearLow: draft.bearLow,
        bearHigh: draft.bearHigh,
        baseLow: draft.baseLow,
        baseHigh: draft.baseHigh,
        bullLow: draft.bullLow,
        bullHigh: draft.bullHigh,
        rationale: draft.rationale,
        targetDate: draft.targetDate
      )
    }

    func updateValuation(
      symbol: String,
      bearLow: Double,
      bearHigh: Double,
      baseLow: Double,
      baseHigh: Double,
      bullLow: Double,
      bullHigh: Double,
      rationale: String?,
      targetDate: String?
    ) async throws -> StockValuationRequest {
      updateValuationCalls += 1
      lastUpdateValuationSymbol = symbol
      lastUpdateValuationBearLow = bearLow
      lastUpdateValuationBearHigh = bearHigh
      lastUpdateValuationBaseLow = baseLow
      lastUpdateValuationBaseHigh = baseHigh
      lastUpdateValuationBullLow = bullLow
      lastUpdateValuationBullHigh = bullHigh
      lastUpdateValuationRationale = rationale
      lastUpdateValuationTargetDate = targetDate
      return try updateValuationResult.get()
    }
  }

  private enum MockError: Error {
    case notConfigured
  }

  private func makeDetails(symbol: String = "AAPL") -> StockDetails {
    StockDetails(
      id: "stock-1",
      symbol: symbol,
      shares: 10,
      buyPrice: 123.45,
      buyDate: "2026-03-13",
      notes: nil
    )
  }

  private func makeValuation(symbol: String = "AAPL") -> StockValuationRequest {
    StockValuationRequest(
      symbol: symbol,
      bearCase: PriceRange(low: 100, high: 120),
      baseCase: PriceRange(low: 130, high: 150),
      bullCase: PriceRange(low: 160, high: 190),
      rationale: "Stable margins with steady growth.",
      targetDate: "2026-12-31"
    )
  }

  func testSaveValuation_WhenNoExistingValuation_CreatesUsingLoadedDetailsSymbol() async {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)
    let expected = makeValuation(symbol: "AAPL")

    viewModel.details = makeDetails(symbol: "AAPL")
    service.createValuationResult = .success(expected)

    let message = await viewModel.saveValuation(
      bearLow: 100,
      bearHigh: 120,
      baseLow: 130,
      baseHigh: 150,
      bullLow: 160,
      bullHigh: 190,
      rationale: "Stable margins with steady growth.",
      targetDate: "2026-12-31"
    )

    XCTAssertNil(message)
    XCTAssertEqual(service.createValuationCalls, 1)
    XCTAssertEqual(service.updateValuationCalls, 0)
    XCTAssertEqual(service.lastCreateValuationSymbol, "AAPL")
    XCTAssertEqual(service.lastCreateValuationBearLow, 100)
    XCTAssertEqual(service.lastCreateValuationBearHigh, 120)
    XCTAssertEqual(service.lastCreateValuationBaseLow, 130)
    XCTAssertEqual(service.lastCreateValuationBaseHigh, 150)
    XCTAssertEqual(service.lastCreateValuationBullLow, 160)
    XCTAssertEqual(service.lastCreateValuationBullHigh, 190)
    XCTAssertEqual(service.lastCreateValuationRationale, "Stable margins with steady growth.")
    XCTAssertEqual(service.lastCreateValuationTargetDate, "2026-12-31")
    XCTAssertEqual(viewModel.valuation, expected)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testSaveValuation_WhenExistingValuation_UpdatesUsingLoadedDetailsSymbol() async {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)
    let expected = makeValuation(symbol: "MSFT")

    viewModel.details = makeDetails(symbol: "MSFT")
    viewModel.valuation = makeValuation(symbol: "MSFT")
    service.updateValuationResult = .success(expected)

    let message = await viewModel.saveValuation(
      bearLow: 100,
      bearHigh: 120,
      baseLow: 130,
      baseHigh: 150,
      bullLow: 160,
      bullHigh: 190,
      rationale: "Stable margins with steady growth.",
      targetDate: "2026-12-31"
    )

    XCTAssertNil(message)
    XCTAssertEqual(service.createValuationCalls, 0)
    XCTAssertEqual(service.updateValuationCalls, 1)
    XCTAssertEqual(service.lastUpdateValuationSymbol, "MSFT")
    XCTAssertEqual(service.lastUpdateValuationBearLow, 100)
    XCTAssertEqual(service.lastUpdateValuationBearHigh, 120)
    XCTAssertEqual(service.lastUpdateValuationBaseLow, 130)
    XCTAssertEqual(service.lastUpdateValuationBaseHigh, 150)
    XCTAssertEqual(service.lastUpdateValuationBullLow, 160)
    XCTAssertEqual(service.lastUpdateValuationBullHigh, 190)
    XCTAssertEqual(service.lastUpdateValuationRationale, "Stable margins with steady growth.")
    XCTAssertEqual(service.lastUpdateValuationTargetDate, "2026-12-31")
    XCTAssertEqual(viewModel.valuation, expected)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testSaveValuation_WhenDetailsMissing_UsesExistingValuationSymbolFallback() async {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)
    let expected = makeValuation(symbol: "NVDA")

    viewModel.valuation = makeValuation(symbol: "NVDA")
    service.updateValuationResult = .success(expected)

    let message = await viewModel.saveValuation(
      bearLow: 100,
      bearHigh: 120,
      baseLow: 130,
      baseHigh: 150,
      bullLow: 160,
      bullHigh: 190,
      rationale: "Stable margins with steady growth.",
      targetDate: "2026-12-31"
    )

    XCTAssertNil(message)
    XCTAssertEqual(service.updateValuationCalls, 1)
    XCTAssertEqual(service.lastUpdateValuationSymbol, "NVDA")
    XCTAssertEqual(service.lastUpdateValuationBearLow, 100)
    XCTAssertEqual(service.lastUpdateValuationBearHigh, 120)
  }

  func testSaveValuation_WhenNoSymbolAvailable_ReturnsErrorWithoutCallingService() async {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)

    let message = await viewModel.saveValuation(
      bearLow: 100,
      bearHigh: 120,
      baseLow: 130,
      baseHigh: 150,
      bullLow: 160,
      bullHigh: 190,
      rationale: "Stable margins with steady growth.",
      targetDate: "2026-12-31"
    )

    XCTAssertEqual(message, "Unable to resolve the stock symbol for this valuation.")
    XCTAssertEqual(service.createValuationCalls, 0)
    XCTAssertEqual(service.updateValuationCalls, 0)
  }

  func testSaveValuation_WhenCreateFails_SetsErrorMessage() async {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)

    viewModel.details = makeDetails(symbol: "AAPL")
    service.createValuationResult = .failure(StockHTTPClient.Error.api("Body symbol must match the route symbol."))

    let message = await viewModel.saveValuation(
      bearLow: 100,
      bearHigh: 120,
      baseLow: 130,
      baseHigh: 150,
      bullLow: 160,
      bullHigh: 190,
      rationale: "Stable margins with steady growth.",
      targetDate: "2026-12-31"
    )

    XCTAssertEqual(message, "Body symbol must match the route symbol.")
    XCTAssertEqual(viewModel.errorMessage, "Body symbol must match the route symbol.")
    XCTAssertFalse(viewModel.isLoading)
  }
}
