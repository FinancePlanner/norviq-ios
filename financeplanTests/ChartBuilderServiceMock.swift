import Foundation
import StockPlanShared

@testable import financeplan

@MainActor
final class ChartBuilderServiceMock: MarketDataServicing {
  var chartResponse = ChartBuilderResponse(period: .annual, periods: [], series: [], companies: [])
  var csvData = Data()
  var error: Error?
  var lastSymbol: String?
  var lastMetrics: [String]?
  var lastPeriod: ChartBuilderPeriodKind?
  var lastLimit: Int?
  var lastCompare: [String]?

  func fetchChartBuilder(
    symbol: String,
    metrics: [String],
    period: ChartBuilderPeriodKind,
    limit: Int,
    compare: [String]
  ) async throws -> ChartBuilderResponse {
    capture(symbol: symbol, metrics: metrics, period: period, limit: limit, compare: compare)
    if let error { throw error }
    return chartResponse
  }

  func fetchChartBuilderCSV(
    symbol: String,
    metrics: [String],
    period: ChartBuilderPeriodKind,
    limit: Int,
    compare: [String]
  ) async throws -> Data {
    capture(symbol: symbol, metrics: metrics, period: period, limit: limit, compare: compare)
    if let error { throw error }
    return csvData
  }

  private func capture(
    symbol: String,
    metrics: [String],
    period: ChartBuilderPeriodKind,
    limit: Int,
    compare: [String]
  ) {
    lastSymbol = symbol
    lastMetrics = metrics
    lastPeriod = period
    lastLimit = limit
    lastCompare = compare
  }
}
