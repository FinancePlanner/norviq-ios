import Foundation
import StockPlanShared
import XCTest

@testable import financeplan

@MainActor
final class ChartBuilderViewModelTests: XCTestCase {
  func testBuildForwardsSelectionAndStoresResponse() async throws {
    let service = ChartBuilderServiceMock()
    service.chartResponse = makeResponse(metricKeys: ["revenue", "freeCashFlow"])
    let viewModel = ChartBuilderViewModel(symbol: "aapl", service: service)
    viewModel.addCompareSymbol(" msft ")

    await viewModel.build()

    XCTAssertEqual(service.lastSymbol, "AAPL")
    XCTAssertEqual(service.lastMetrics, ["revenue", "freeCashFlow"])
    XCTAssertEqual(service.lastPeriod, .annual)
    XCTAssertEqual(service.lastLimit, 10)
    XCTAssertEqual(service.lastCompare, ["MSFT"])
    XCTAssertEqual(viewModel.response, service.chartResponse)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testTTMRemovesUnsupportedMetrics() throws {
    let viewModel = ChartBuilderViewModel(symbol: "AAPL", service: ChartBuilderServiceMock())
    let growthMetric = try XCTUnwrap(ChartBuilderMetricCatalog.byKey["revenueGrowth"])
    viewModel.toggleMetric(growthMetric)
    XCTAssertTrue(viewModel.selectedMetricKeys.contains(growthMetric.key))

    viewModel.period = .ttm

    XCTAssertFalse(viewModel.selectedMetricKeys.contains(growthMetric.key))
    XCTAssertTrue(viewModel.selectedMetricKeys.allSatisfy {
      ChartBuilderMetricCatalog.byKey[$0]?.supportsTTM == true
    })
  }

  func testCompareSymbolsNormalizeDeduplicateAndRespectCap() {
    let viewModel = ChartBuilderViewModel(symbol: "AAPL", service: ChartBuilderServiceMock())

    viewModel.addCompareSymbol(" msft ")
    viewModel.addCompareSymbol("MSFT")
    viewModel.addCompareSymbol("aapl")
    viewModel.addCompareSymbol("goog")
    viewModel.addCompareSymbol("amzn")
    viewModel.addCompareSymbol("meta")

    XCTAssertEqual(viewModel.compareSymbols, ["MSFT", "GOOG", "AMZN"])
    XCTAssertEqual(viewModel.errorMessage, "Compare up to 3 peer symbols.")
  }

  func testExportCSVWritesShareableFile() async throws {
    let service = ChartBuilderServiceMock()
    service.csvData = Data("Period,Revenue\nFY2024,391035000000\n".utf8)
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "chart-builder-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let viewModel = ChartBuilderViewModel(
      symbol: "AAPL",
      service: service,
      exportDirectory: directory
    )
    viewModel.period = .quarter

    await viewModel.exportCSV()

    let exportURL = try XCTUnwrap(viewModel.exportItem?.url)
    XCTAssertEqual(exportURL.lastPathComponent, "AAPL-chart-builder-quarter.csv")
    XCTAssertEqual(try Data(contentsOf: exportURL), service.csvData)
    XCTAssertEqual(service.lastPeriod, .quarter)
    XCTAssertEqual(service.lastLimit, 20)
  }

  func testBuildFailureSurfacesMessage() async {
    let service = ChartBuilderServiceMock()
    service.error = ChartBuilderTestError.unavailable
    let viewModel = ChartBuilderViewModel(symbol: "AAPL", service: service)

    await viewModel.build()

    XCTAssertNil(viewModel.response)
    XCTAssertEqual(viewModel.errorMessage, ChartBuilderTestError.unavailable.localizedDescription)
  }

  private func makeResponse(metricKeys: [String]) -> ChartBuilderResponse {
    ChartBuilderResponse(
      period: .annual,
      periods: [
        ChartBuilderPeriod(
          label: "FY2024",
          fiscalYear: "2024",
          fiscalPeriod: "FY",
          endDate: "2024-09-28"
        )
      ],
      series: metricKeys.map { key in
        guard let metric = ChartBuilderMetricCatalog.byKey[key] else {
          fatalError("Missing chart-builder test metric: \(key)")
        }
        return ChartBuilderSeries(
          symbol: "AAPL",
          metricKey: key,
          label: metric.label,
          format: metric.format,
          currency: metric.format == .currency ? "USD" : nil,
          values: [1],
          growth: nil
        )
      },
      companies: [ChartBuilderCompany(symbol: "AAPL", name: "Apple Inc.", currency: "USD")]
    )
  }
}
