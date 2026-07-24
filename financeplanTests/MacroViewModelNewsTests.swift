import Foundation
import StockPlanShared
import XCTest

@testable import financeplan

@MainActor
final class MacroViewModelNewsTests: XCTestCase {
  func testLoadPopulatesNewsAlongsideMacroData() async {
    let marketMock = NewsMarketDataServiceMock()
    marketMock.fetchMarketNewsResult = .success([
      StockNews(
        title: "Fed holds rates steady",
        url: "https://example.com/fed",
        date: "2026-07-24T10:00:00Z",
        imageURL: nil,
        source: "Reuters",
        summary: nil,
        newsId: nil,
        symbol: "GENERAL"
      )
    ])
    let viewModel = MacroViewModel(macroService: MacroServiceNewsMock(), marketDataService: marketMock)

    await viewModel.load(country: "US")

    XCTAssertEqual(viewModel.news.map(\.title), ["Fed holds rates steady"])
    XCTAssertEqual(marketMock.fetchMarketNewsCalls, 1)
  }

  func testNewsFailureLeavesNewsEmptyAndMacroIntact() async {
    let marketMock = NewsMarketDataServiceMock()
    marketMock.fetchMarketNewsResult = .failure(NewsMockError.unavailable)
    let viewModel = MacroViewModel(macroService: MacroServiceNewsMock(), marketDataService: marketMock)

    await viewModel.load(country: "US")

    XCTAssertTrue(viewModel.news.isEmpty)
    XCTAssertNotNil(viewModel.snapshot)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testRelativeDateParsingIsDefensive() {
    XCTAssertNotNil(MacroNewsDateFormatting.parse("2026-07-24T10:00:00Z"))
    XCTAssertNotNil(MacroNewsDateFormatting.parse("2026-07-24 10:00:00"))
    XCTAssertNotNil(MacroNewsDateFormatting.parse("2026-07-24"))
    XCTAssertNil(MacroNewsDateFormatting.parse("garbage"))
    XCTAssertNil(MacroNewsDateFormatting.parse(""))
    XCTAssertNil(MacroNewsDateFormatting.relative(from: "garbage"))
  }
}

private enum NewsMockError: Error {
  case unavailable
}

private final class NewsMarketDataServiceMock: MarketDataServicing, @unchecked Sendable {
  var fetchMarketNewsCalls = 0
  var fetchMarketNewsResult: Result<[StockNews], Error> = .success([])

  func fetchMarketNews(limit _: Int?) async throws -> [StockNews] {
    fetchMarketNewsCalls += 1
    return try fetchMarketNewsResult.get()
  }
}

private final class MacroServiceNewsMock: MacroServicing, @unchecked Sendable {
  func getCurrentInflation(country _: String?) async throws -> InflationSnapshotResponse {
    InflationSnapshotResponse(
      country: "US",
      currency: "USD",
      asOf: "2026-06-01",
      updatedAt: "2026-07-24T00:00:00Z",
      source: "live",
      headline: InflationGaugeDTO(
        name: "Headline CPI",
        nowValue: 2.7,
        officialValue: nil,
        officialAsOf: nil,
        gap: nil,
        unit: "percent",
        colVariant: nil,
        cumulativeSinceBase: nil,
        basePeriod: nil
      ),
      gauges: [],
      components: [],
      topMovers: [],
      notes: nil,
      nextPrintCountdown: nil
    )
  }

  func getTopMovers(country _: String?, focus _: String?) async throws -> [TopMoverDTO] { [] }

  func getSeries(country _: String?, series _: String, limit _: Int?) async throws -> MacroSeriesResponse {
    throw NewsMockError.unavailable
  }

  func getPersonalInflation(country _: String?, months _: Int) async throws -> PersonalInflationResponse {
    throw NewsMockError.unavailable
  }

  func getSupportedCountries() async throws -> [SupportedCountry] { [] }

  func getFedWatch() async throws -> FedWatchResponse {
    throw NewsMockError.unavailable
  }

  func getItems(country _: String?) async throws -> MacroItemsResponse {
    throw NewsMockError.unavailable
  }

  func getItemSeries(itemId _: String, country _: String?, limit _: Int?) async throws -> MacroItemSeriesResponse {
    throw NewsMockError.unavailable
  }

  func getHousing(country _: String?) async throws -> HousingHubResponse {
    throw NewsMockError.unavailable
  }

  func getEconomy(country _: String?) async throws -> EconomyHubResponse {
    throw NewsMockError.unavailable
  }

  func getPolicyWatch(country _: String?) async throws -> PolicyWatchResponse {
    throw NewsMockError.unavailable
  }
}
