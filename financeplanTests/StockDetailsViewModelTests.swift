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
    var fetchStockDetailsResult: Result<StockDetails, Error> = .failure(MockError.notConfigured)
    var fetchStockHistoryResult: Result<[StockHistory], Error> = .success([])
    var fetchStockNewsResult: Result<[StockNews], Error> = .success([])
    var getValuationResult: Result<StockValuationRequest, Error> = .failure(StockHTTPClient.Error.invalidStatus(404))
    var updateStockResult: Result<StockResponse, Error> = .failure(MockError.notConfigured)

    func create(stock _: StockRequest) async throws -> StockResponse {
      throw MockError.notConfigured
    }

    func bulkCreate(stocks _: [StockRequest]) async throws -> BulkStockResponse {
      throw MockError.notConfigured
    }

    func fetchPortfolio() async throws -> [StockResponse] {
      throw MockError.notConfigured
    }

    func fetchStockDetails(stockId _: String) async throws -> StockDetails {
      try fetchStockDetailsResult.get()
    }

    func fetchStockHistory(symbol _: String) async throws -> [StockHistory] {
      try fetchStockHistoryResult.get()
    }

    func fetchStockNews(symbol _: String) async throws -> [StockNews] {
      try fetchStockNewsResult.get()
    }

    func updateStock(_ stock: StockResponse) async throws -> StockResponse {
      switch updateStockResult {
      case let .success(response):
        return response
      case let .failure(error):
        throw error
      }
    }

    func delete(id _: String) async throws {}

    func fetchWatchlist() async throws -> [WatchlistItemResponse] {
      throw MockError.notConfigured
    }

    func createWatchlistItem(_ request: WatchlistItemRequest) async throws -> WatchlistItemResponse {
      throw MockError.notConfigured
    }

    func updateWatchlistItem(
      id _: String,
      request _: WatchlistItemUpdateRequest
    ) async throws -> WatchlistItemResponse {
      throw MockError.notConfigured
    }

    func deleteWatchlistItem(id _: String) async throws {
      throw MockError.notConfigured
    }

    func getValuation(symbol _: String) async throws -> StockValuationRequest {
      try getValuationResult.get()
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

  private final class MarketDataServiceMock: MarketDataServicing {
    var fetchCompanyProfileResult: Result<CompanyProfileResponse, Error> = .failure(MockError.notConfigured)
    var fetchQuoteResult: Result<QuoteResponse, Error> = .failure(MockError.notConfigured)

    func fetchCompanyProfile(symbol _: String) async throws -> CompanyProfileResponse {
      try fetchCompanyProfileResult.get()
    }

    func fetchQuote(symbol _: String) async throws -> QuoteResponse {
      try fetchQuoteResult.get()
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

  private func makeHistory(date: String = "2026-03-26") -> StockHistory {
    StockHistory(
      date: date,
      open: 120,
      high: 128,
      low: 118,
      close: 125,
      volume: 1_250_000
    )
  }

  private func makeNews(
    title: String = "Apple expands services revenue",
    date: String = "2026-03-26"
  ) -> StockNews {
    StockNews(
      title: title,
      url: "https://example.com/apple-services",
      date: date
    )
  }

  func testShareSnapshot_BuildsStructuredExportText() {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)

    viewModel.details = StockDetails(
      id: "stock-1",
      symbol: "AAPL",
      shares: 10,
      buyPrice: 123.45,
      buyDate: "2026-03-13",
      notes: "Watching margins and installed base growth."
    )
    viewModel.valuation = makeValuation(symbol: "AAPL")
    viewModel.history = [makeHistory()]
    viewModel.news = [
      makeNews(),
      makeNews(title: "Analysts review iPhone demand", date: "2026-03-24"),
    ]

    let snapshot = viewModel.shareSnapshot
    let expectedPositionLine = "Position: 10 shares @ \(123.45.currency)"
    let expectedCostBasisLine = "Cost basis: \((10.0 * 123.45).currency)"
    let expectedBearLine = "Bear: \(100.0.currency) - \(120.0.currency)"
    let expectedLatestCloseLine = "Latest close: \(125.0.currency)"

    XCTAssertEqual(snapshot?.title, "AAPL stock snapshot")
    XCTAssertTrue(snapshot?.body.contains("position snapshot") == true)
    XCTAssertTrue(snapshot?.body.contains(expectedPositionLine) == true)
    XCTAssertTrue(snapshot?.body.contains(expectedCostBasisLine) == true)
    XCTAssertTrue(snapshot?.body.contains("Valuation") == true)
    XCTAssertTrue(snapshot?.body.contains(expectedBearLine) == true)
    XCTAssertTrue(snapshot?.body.contains(expectedLatestCloseLine) == true)
    XCTAssertTrue(snapshot?.body.contains("Recent news") == true)
    XCTAssertTrue(snapshot?.body.contains("Apple expands services revenue") == true)
  }

  func testShareSnapshot_IsNilWithoutLoadedDetails() {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)

    XCTAssertNil(viewModel.shareSnapshot)
  }

  func testDeletePosition_ClearsDetails() async {
    let service = StockServiceMock()
    let initial = makeDetails(symbol: "AAPL")
    service.fetchStockDetailsResult = .success(initial)

    let viewModel = StockDetailsViewModel(service: service)
    await viewModel.load(stockId: initial.id)

    let ok = await viewModel.deletePosition()

    XCTAssertTrue(ok)
    XCTAssertNil(viewModel.details)
    XCTAssertTrue(viewModel.history.isEmpty)
    XCTAssertTrue(viewModel.news.isEmpty)
    XCTAssertNil(viewModel.valuation)
    XCTAssertNil(viewModel.marketSnapshot)
  }

  func testSavePosition_UpdatesDetailsFromService() async {
    let service = StockServiceMock()
    let initial = makeDetails(symbol: "AAPL")
    let updated = StockResponse(
      id: initial.id,
      symbol: initial.symbol,
      shares: 25,
      buyPrice: initial.buyPrice,
      buyDate: initial.buyDate,
      notes: initial.notes
    )
    service.fetchStockDetailsResult = .success(initial)
    service.updateStockResult = .success(updated)

    let viewModel = StockDetailsViewModel(service: service)
    await viewModel.load(stockId: initial.id)

    let ok = await viewModel.savePosition(updated)

    XCTAssertTrue(ok)
    XCTAssertEqual(viewModel.details?.shares, 25)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testLoad_PopulatesMockInsightsAndDefaultPeers() async throws {
    let service = StockServiceMock()
    let marketDataService = MarketDataServiceMock()
    let viewModel = StockDetailsViewModel(service: service, marketDataService: marketDataService)

    service.fetchStockDetailsResult = .success(makeDetails(symbol: "META"))
    service.fetchStockHistoryResult = .success([makeHistory()])
    service.fetchStockNewsResult = .success([makeNews()])
    service.getValuationResult = .success(makeValuation(symbol: "META"))
    marketDataService.fetchCompanyProfileResult = .success(
      CompanyProfileResponse(
        country: "US",
        currency: "USD",
        estimateCurrency: "USD",
        exchange: "NASDAQ",
        finnhubIndustry: "Communication Services",
        ipo: "2012-05-18",
        logo: "https://example.com/meta.png",
        marketCapitalization: 2_500_000,
        name: "Meta Platforms, Inc.",
        phone: "16505434800",
        shareOutstanding: 2_500,
        ticker: "META",
        weburl: "https://investor.fb.com"
      )
    )
    marketDataService.fetchQuoteResult = .success(
      QuoteResponse(
        symbol: "META",
        currency: "USD",
        currentPrice: 612.42,
        change: 7.15,
        percentChange: 1.18,
        high: 615.20,
        low: 606.30,
        open: 608.10,
        previousClose: 605.27,
        timestamp: 1_775_073_600
      )
    )

    await viewModel.load(stockId: "stock-1")

    XCTAssertEqual(viewModel.companyProfile?.ticker, "META")
    XCTAssertEqual(viewModel.primaryComparisonProfile?.symbol, "META")
    XCTAssertEqual(viewModel.selectedPeerSymbols.count, 2)
    XCTAssertEqual(viewModel.comparisonProfiles.count, 3)
    XCTAssertNotNil(viewModel.projectionScenario(.base))
    XCTAssertEqual(viewModel.projectionScenario(.base)?.years.count, 5)
    XCTAssertEqual(viewModel.projectionScenario(.base)?.years.last?.year, 2028)
    XCTAssertNotNil(viewModel.marketSnapshot)
    let currentPrice = try XCTUnwrap(viewModel.marketSnapshot?.currentPrice)
    XCTAssertEqual(currentPrice, 612.42, accuracy: 0.001)
  }

  func testMarketSnapshot_WhenChangeFieldsMissing_ComputesChangeAndPercent() throws {
    let snapshot = StockMarketSnapshot(
      symbol: "TEST",
      currency: "USD",
      currentPrice: 261.74,
      high: 263.31,
      low: 260.68,
      open: 261.07,
      previousClose: 259.45,
      timestamp: 1_582_641_000
    )

    XCTAssertEqual(snapshot.resolvedChange, 2.29, accuracy: 0.001)
    let resolvedPercentChange = try XCTUnwrap(snapshot.resolvedPercentChange)
    XCTAssertEqual(resolvedPercentChange, 2.29 / 259.45, accuracy: 0.0001)
    XCTAssertGreaterThan(snapshot.rangeProgress, 0)
    XCTAssertLessThan(snapshot.rangeProgress, 1)
  }

  func testMarketSnapshot_WhenEndpointProvidesPercentagePoints_NormalizesForDisplay() throws {
    let snapshot = StockMarketSnapshot(
      symbol: "ZETA",
      currency: "USD",
      currentPrice: 15.73,
      change: -0.19,
      percentChange: -1.1935,
      high: 16.3,
      low: 15.53,
      open: 16.2,
      previousClose: 15.92,
      timestamp: 1_775_073_600
    )

    XCTAssertEqual(snapshot.resolvedChange, -0.19, accuracy: 0.0001)
    let resolvedPercentChange = try XCTUnwrap(snapshot.resolvedPercentChange)
    XCTAssertEqual(resolvedPercentChange, -0.011935, accuracy: 0.000001)
  }

  func testUpdatePeerSymbol_WhenSelectingExistingPeer_SwapsVisibleColumns() async {
    let service = StockServiceMock()
    let viewModel = StockDetailsViewModel(service: service)

    service.fetchStockDetailsResult = .success(makeDetails(symbol: "META"))
    await viewModel.load(stockId: "stock-1")

    let firstPeer = viewModel.selectedPeerSymbol(at: 0)
    let secondPeer = viewModel.selectedPeerSymbol(at: 1)

    viewModel.updatePeerSymbol(secondPeer, slot: 0)

    XCTAssertEqual(viewModel.selectedPeerSymbol(at: 0), secondPeer)
    XCTAssertEqual(viewModel.selectedPeerSymbol(at: 1), firstPeer)
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
