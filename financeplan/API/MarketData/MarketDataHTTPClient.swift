import AnyAPI
import Foundation
import OSLog
import StockPlanShared

protocol MarketDataURLSessionProtocol: HTTPClientSession {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: MarketDataURLSessionProtocol {}

// MARK: - Client

struct MarketDataHTTPClient: Sendable {
  enum Error: HTTPClientError {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)

    nonisolated var errorDescription: String? {
      switch self {
      case .invalidResponse:
        return "Invalid server response."
      case let .invalidStatus(code):
        return "Request failed (\(code))."
      case let .unauthorized(message):
        return message ?? "Your session expired. Please sign in again."
      case let .api(message):
        return message
      }
    }

    var isUnauthorized: Bool {
      if case .unauthorized = self {
        return true
      }
      return false
    }

    nonisolated var statusCode: Int? {
        if case let .invalidStatus(code) = self { return code }
        return nil
    }

    nonisolated static func == (lhs: Error, rhs: Error) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse): return true
        case let (.invalidStatus(l), .invalidStatus(r)): return l == r
        case let (.unauthorized(l), .unauthorized(r)): return l == r
        case let (.api(l), .api(r)): return l == r
        default: return false
        }
    }

    static func makeInvalidResponse() -> Error { .invalidResponse }
    static func makeInvalidStatus(_ code: Int) -> Error { .invalidStatus(code) }
    static func makeUnauthorized(_ message: String?) -> Error { .unauthorized(message) }
    static func makeAPI(_ message: String) -> Error { .api(message) }
  }

  private let client: BaseHTTPClient

  init(baseURL: URL, session: any HTTPClientSession = URLSession.shared, authTokenProvider: @escaping @Sendable () async -> String? = { nil }) {
    self.client = BaseHTTPClient(
        baseURL: baseURL,
        session: session,
        authTokenProvider: authTokenProvider,
        logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "MarketDataHTTPClient"),
        decoder: .stockPlanShared
    )
  }

  func fetchCompanyProfile(symbol: String) async throws -> CompanyProfileResponse {
    try await client.call(GetCompanyProfileEndpoint(symbol: symbol), errorType: Error.self)
  }

  func fetchQuote(symbol: String) async throws -> QuoteResponse {
    try await client.call(GetQuoteEndpoint(symbol: symbol), errorType: Error.self)
  }

  func call<E: Endpoint>(_ endpoint: E) async throws -> E.Response where E.Response: Codable & Sendable {
    try await client.call(endpoint, errorType: Error.self)
  }

  func callWithoutResponse<E: Endpoint>(_ endpoint: E) async throws where E.Response: Codable {
    try await client.callWithoutResponse(endpoint, errorType: Error.self)
  }

  func fetchAnalystConsensus(symbol: String) async throws -> StockAnalystConsensus {
    let response = try await client.call(GetGradesConsensusEndpoint(symbol: symbol), errorType: Error.self)
    guard let consensus = response.first else {
      throw Error.api("No analyst consensus is available for this stock right now.")
    }
    return consensus
  }

  func fetchBasicFinancials(symbol: String) async throws -> StockBasicFinancials {
    let response = try await client.call(GetBasicFinancialsEndpoint(symbol: symbol), errorType: Error.self)
    return response.basicFinancials
  }

  func fetchAnalysisMetrics(
    symbol: String,
    wacc: Double? = nil,
    terminalGrowthRate: Double? = nil,
    terminalMargin: Double? = nil,
    fcfMarginAssumption: Double? = nil
  ) async throws -> StockAnalysisMetrics {
    try await client.call(GetAnalysisMetricsEndpoint(
      symbol: symbol,
      wacc: wacc,
      terminalGrowthRate: terminalGrowthRate,
      terminalMargin: terminalMargin,
      fcfMarginAssumption: fcfMarginAssumption
    ), errorType: Error.self)
  }

  func fetchMarketCompare(symbols: [String]) async throws -> [StockAnalysisMetrics] {
    try await client.call(GetMarketCompareEndpoint(symbols: symbols), errorType: Error.self)
  }

  func fetchBalanceSheetStatement(symbol: String, limit: Int? = nil, period: String? = nil) async throws -> [BalanceSheetStatementResponse] {
    try await client.call(GetBalanceSheetStatementEndpoint(symbol: symbol, limit: limit, period: period), errorType: Error.self)
  }

  func fetchCashFlowStatement(symbol: String, limit: Int? = nil, period: String? = nil) async throws -> [CashFlowStatementResponse] {
    try await client.call(GetCashFlowStatementEndpoint(symbol: symbol, limit: limit, period: period), errorType: Error.self)
  }

  func fetchRatios(symbol: String, limit: Int? = nil, period: String? = nil) async throws -> [RatiosResponse] {
    try await client.call(GetRatiosEndpoint(symbol: symbol, limit: limit, period: period), errorType: Error.self)
  }

  func fetchRatiosTTM(symbol: String) async throws -> [RatiosTTMResponse] {
    try await client.call(GetRatiosTTMEndpoint(symbol: symbol), errorType: Error.self)
  }

  func fetchFinancialGrowth(symbol: String, limit: Int? = nil, period: String? = nil) async throws -> [FinancialGrowthResponse] {
    try await client.call(GetFinancialGrowthEndpoint(symbol: symbol, limit: limit, period: period), errorType: Error.self)
  }

  func fetchAnalystEstimates(symbol: String, limit: Int? = nil, period: String? = nil) async throws -> [AnalystEstimatesResponse] {
    try await client.call(GetAnalystEstimatesEndpoint(symbol: symbol, limit: limit, period: period), errorType: Error.self)
  }

  func fetchStockEarnings(symbol: String, limit: Int) async throws -> [EarningsEvent] {
    try await client.call(GetStockEarningsEndpoint(symbol: symbol, limit: limit), errorType: Error.self)
  }

  func fetchStockEarningsTranscript(symbol: String, date: String) async throws -> EarningsTranscript {
    try await client.call(GetStockEarningsTranscriptEndpoint(symbol: symbol, date: date), errorType: Error.self)
  }

  func fetchEarningsCalendar(from: String, to: String) async throws -> [EarningsEvent] {
    try await client.call(GetEarningsCalendarEndpoint(from: from, to: to), errorType: Error.self)
  }

  func fetchMarketNews(limit: Int?) async throws -> [StockNews] {
    try await client.call(GetGeneralMarketNewsEndpoint(limit: limit), errorType: Error.self)
  }

  func fetchPriceChart(symbol: String, range: String) async throws -> PriceChartSeries {
    try await client.call(GetPriceChartEndpoint(symbol: symbol, range: range), errorType: Error.self)
  }

  func fetchPriceChartComparison(symbols: [String], range: String) async throws -> PriceChartComparisonResponse {
    try await client.call(GetPriceChartComparisonEndpoint(symbols: symbols, range: range), errorType: Error.self)
  }

  func searchAssets(query: String, limit: Int) async throws -> [SearchResultResponse] {
    try await client.call(SearchAssetsEndpoint(query: query, limit: limit), errorType: Error.self)
  }
}

private struct SearchAssetsEndpoint: Endpoint {
  typealias Response = [SearchResultResponse]

  let query: String
  let limit: Int

  var method: HTTPMethod { .get }
  var path: String { "/v1/assets/search" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["q": query, "limit": limit]
  }
}

struct MarketBasicFinancialsResponse: Sendable {
  let series: MarketBasicFinancialSeriesResponse
  let metricType: String
  let metric: [String: MarketBasicFinancialMetricValue]
  let symbol: String

  var basicFinancials: StockBasicFinancials {
    StockBasicFinancials(
      symbol: symbol.uppercased(),
      metricType: metricType,
      currencyCode: metric.string("currency"),
      peRatio: resolvedPERatio,
      netMargin: resolvedNetMargin,
      currentRatio: resolvedCurrentRatio,
      beta: metric.number("beta"),
      fiftyTwoWeekHigh: metric.number("52WeekHigh"),
      fiftyTwoWeekLow: metric.number("52WeekLow"),
      fiftyTwoWeekLowDate: metric.string("52WeekLowDate"),
      fiftyTwoWeekPriceReturnDaily: metric.number("52WeekPriceReturnDaily"),
      tenDayAverageTradingVolume: metric.number("10DayAverageTradingVolume"),
      salesPerShareAnnual: series.points(for: "salesPerShare", frequency: .annual),
      currentRatioAnnual: series.points(for: "currentRatio", frequency: .annual),
      netMarginAnnual: series.points(for: "netMargin", frequency: .annual)
    )
  }

  private var resolvedPERatio: Double? {
    metric.number("peTTM")
      ?? metric.number("peBasicExclExtraTTM")
      ?? metric.number("peExclExtraTTM")
      ?? metric.number("peAnnual")
      ?? metric.number("peNormalizedAnnual")
      ?? metric.number("forwardPE")
  }

  private var resolvedNetMargin: Double? {
    metric.percentFraction("netProfitMarginTTM")
      ?? metric.percentFraction("netProfitMarginAnnual")
      ?? series.latestValue(for: "netMargin", frequency: .quarterly)
      ?? series.latestValue(for: "netMargin", frequency: .annual)
  }

  private var resolvedCurrentRatio: Double? {
    metric.number("currentRatioQuarterly")
      ?? metric.number("currentRatioAnnual")
      ?? series.latestValue(for: "currentRatio", frequency: .quarterly)
      ?? series.latestValue(for: "currentRatio", frequency: .annual)
  }
}

nonisolated extension MarketBasicFinancialsResponse: Codable {}

nonisolated extension MarketBasicFinancialSeriesResponse: Codable {}

struct MarketBasicFinancialSeriesResponse: Sendable {
  let annual: [String: [MarketBasicFinancialSeriesValue]]
  let quarterly: [String: [MarketBasicFinancialSeriesValue]]

  fileprivate func points(
    for key: String,
    frequency: MarketBasicFinancialSeriesFrequency
  ) -> [StockBasicFinancialSeriesPoint] {
    values(for: key, frequency: frequency)
      .sorted { $0.period > $1.period }
      .map { StockBasicFinancialSeriesPoint(period: $0.period, value: $0.value) }
  }

  fileprivate func latestValue(
    for key: String,
    frequency: MarketBasicFinancialSeriesFrequency
  ) -> Double? {
    values(for: key, frequency: frequency)
      .sorted { $0.period > $1.period }
      .first?
      .value
  }

  private func values(
    for key: String,
    frequency: MarketBasicFinancialSeriesFrequency
  ) -> [MarketBasicFinancialSeriesValue] {
    switch frequency {
    case .annual:
      annual[key] ?? []
    case .quarterly:
      quarterly[key] ?? []
    }
  }
}

struct MarketBasicFinancialSeriesValue: Codable, Equatable, Sendable {
  let period: String
  let value: Double

  private enum CodingKeys: String, CodingKey {
    case period
    case value = "v"
  }
}

enum MarketBasicFinancialSeriesFrequency: Sendable {
  case annual
  case quarterly
}

enum MarketBasicFinancialMetricValue: Equatable, Sendable {
  case number(Double)
  case string(String)
  case null

  nonisolated init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if container.decodeNil() {
      self = .null
      return
    }

    if let value = try? container.decode(Double.self) {
      self = .number(value)
      return
    }

    if let value = try? container.decode(Int.self) {
      self = .number(Double(value))
      return
    }

    if let value = try? container.decode(String.self) {
      self = .string(value)
      return
    }

    throw DecodingError.typeMismatch(
      MarketBasicFinancialMetricValue.self,
      DecodingError.Context(
        codingPath: decoder.codingPath,
        debugDescription: "Expected a number, string, or null basic financial metric value."
      )
    )
  }

  nonisolated func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case let .number(value):
      try container.encode(value)
    case let .string(value):
      try container.encode(value)
    case .null:
      try container.encodeNil()
    }
  }
}

nonisolated extension MarketBasicFinancialMetricValue: Codable {}

private extension Dictionary where Key == String, Value == MarketBasicFinancialMetricValue {
  func number(_ key: String) -> Double? {
    guard let value = self[key] else { return nil }
    guard case let .number(number) = value else { return nil }
    return number
  }

  func string(_ key: String) -> String? {
    guard let value = self[key] else { return nil }
    guard case let .string(string) = value else { return nil }
    return string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : string
  }

  func percentFraction(_ key: String) -> Double? {
    number(key).map { $0 / 100 }
  }
}
