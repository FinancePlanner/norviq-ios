import AnyAPI
import Foundation
import OSLog
import StockPlanShared

protocol MarketDataURLSessionProtocol {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: MarketDataURLSessionProtocol {}

private let marketDataHTTPLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
  category: "MarketDataHTTPClient"
)

struct MarketDataHTTPClient {
  enum Error: LocalizedError, Equatable {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)

    var errorDescription: String? {
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
  }

  let baseURL: URL
  let session: MarketDataURLSessionProtocol
  let authTokenProvider: () -> String?

  init(
    baseURL: URL,
    session: MarketDataURLSessionProtocol = URLSession.shared,
    authTokenProvider: @escaping () -> String? = { nil }
  ) {
    self.baseURL = baseURL
    self.session = session
    self.authTokenProvider = authTokenProvider
  }

  func fetchCompanyProfile(symbol: String) async throws -> CompanyProfileResponse {
    try await call(GetCompanyProfileEndpoint(symbol: symbol))
  }

  func fetchQuote(symbol: String) async throws -> QuoteResponse {
    try await call(GetQuoteEndpoint(symbol: symbol))
  }

  func fetchAnalystConsensus(symbol: String) async throws -> StockAnalystConsensus {
    let response = try await call(GetGradesConsensusEndpoint(symbol: symbol))
    guard let consensus = response.first else {
      throw Error.api("No analyst consensus is available for this stock right now.")
    }
    return consensus
  }

  func fetchBasicFinancials(symbol: String) async throws -> StockBasicFinancials {
    let response = try await call(GetBasicFinancialsEndpoint(symbol: symbol))
    return response.basicFinancials
  }

  func fetchAnalysisMetrics(
    symbol: String,
    wacc: Double? = nil,
    terminalGrowthRate: Double? = nil,
    terminalMargin: Double? = nil,
    fcfMarginAssumption: Double? = nil
  ) async throws -> StockAnalysisMetrics {
    try await call(GetAnalysisMetricsEndpoint(
      symbol: symbol,
      wacc: wacc,
      terminalGrowthRate: terminalGrowthRate,
      terminalMargin: terminalMargin,
      fcfMarginAssumption: fcfMarginAssumption
    ))
  }

  func fetchMarketCompare(symbols: [String]) async throws -> [StockAnalysisMetrics] {
    try await call(GetMarketCompareEndpoint(symbols: symbols))
  }

  func fetchBalanceSheetStatement(symbol: String, limit: Int? = nil, period: String? = nil) async throws -> [BalanceSheetStatementResponse] {
    try await call(GetBalanceSheetStatementEndpoint(symbol: symbol, limit: limit, period: period))
  }

  func fetchCashFlowStatement(symbol: String, limit: Int? = nil, period: String? = nil) async throws -> [CashFlowStatementResponse] {
    try await call(GetCashFlowStatementEndpoint(symbol: symbol, limit: limit, period: period))
  }

  func fetchRatios(symbol: String, limit: Int? = nil, period: String? = nil) async throws -> [RatiosResponse] {
    try await call(GetRatiosEndpoint(symbol: symbol, limit: limit, period: period))
  }

  func fetchRatiosTTM(symbol: String) async throws -> [RatiosTTMResponse] {
    try await call(GetRatiosTTMEndpoint(symbol: symbol))
  }

  func fetchFinancialGrowth(symbol: String, limit: Int? = nil, period: String? = nil) async throws -> [FinancialGrowthResponse] {
    try await call(GetFinancialGrowthEndpoint(symbol: symbol, limit: limit, period: period))
  }

  func fetchAnalystEstimates(symbol: String, limit: Int? = nil, period: String? = nil) async throws -> [AnalystEstimatesResponse] {
    try await call(GetAnalystEstimatesEndpoint(symbol: symbol, limit: limit, period: period))
  }

  func fetchStockEarnings(symbol: String, limit: Int) async throws -> [EarningsEvent] {
    try await call(GetStockEarningsEndpoint(symbol: symbol, limit: limit))
  }

  func fetchEarningsCalendar(from: String, to: String) async throws -> [EarningsEvent] {
    try await call(GetEarningsCalendarEndpoint(from: from, to: to))
  }

  func fetchMarketNews(limit: Int?) async throws -> [StockNews] {
    try await call(GetGeneralMarketNewsEndpoint(limit: limit))
  }

  func fetchPriceChart(symbol: String, range: String) async throws -> PriceChartSeries {
    try await call(GetPriceChartEndpoint(symbol: symbol, range: range))
  }

  func fetchPriceChartComparison(symbols: [String], range: String) async throws -> PriceChartComparisonResponse {
    try await call(GetPriceChartComparisonEndpoint(symbols: symbols, range: range))
  }

  func call<E: Endpoint>(_ endpoint: E) async throws -> E.Response where E.Response: Codable {
    let data = try await perform(endpoint)
    do {
      return try endpoint.decode(data)
    } catch {
      if let envelope = try? endpoint.decoder.decode(HTTPEnvelope<E.Response>.self, from: data) {
        if let payload = envelope.data {
          return payload
        }
        if let message = envelope.message, !message.isEmpty {
          throw Error.api(message)
        }
      }
      throw error
    }
  }

  private func perform<E: Endpoint>(_ endpoint: E) async throws -> Data {
    let request = try makeURLRequest(for: endpoint)
    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw Error.invalidResponse
    }

    marketDataHTTPLogger.debug(
      "MarketData response [\(endpoint.path, privacy: .public)] status=\(httpResponse.statusCode, privacy: .public)"
    )

    guard (200 ..< 300).contains(httpResponse.statusCode) else {
      let message = errorMessage(from: data)

      if httpResponse.statusCode == 401 {
        throw Error.unauthorized(message)
      }

      if let message, !message.isEmpty {
        throw Error.api(message)
      }
      throw Error.invalidStatus(httpResponse.statusCode)
    }

    return data
  }

  private func errorMessage(from data: Data) -> String? {
    APIErrorDecoding.message(from: data)
  }

  private func makeURLRequest<E: Endpoint>(for endpoint: E) throws -> URLRequest {
    let normalizedPath = endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let base = baseURL.appendingPathComponent(normalizedPath)
    let parameters = try endpoint.asParameters()
    let url = try url(for: endpoint.method, baseURL: base, parameters: parameters)

    var request = URLRequest(url: url)
    request.httpMethod = endpoint.method.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let token = authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    for header in endpoint.headers {
      request.setValue(header.value, forHTTPHeaderField: header.name)
    }

    if endpoint.method != .get, !parameters.isEmpty {
      request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
    }

    return request
  }

  private func url(for method: HTTPMethod, baseURL: URL, parameters: Parameters) throws -> URL {
    guard method == .get, !parameters.isEmpty else {
      return baseURL
    }

    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    components?.queryItems = parameters.compactMap { key, value in
      URLQueryItem(name: key, value: String(describing: value))
    }

    guard let url = components?.url else {
      throw Error.invalidResponse
    }

    return url
  }
}

private struct HTTPEnvelope<T: Codable>: Codable {
  let data: T?
  let message: String?
}

struct MarketBasicFinancialsResponse: Codable, Sendable {
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

struct MarketBasicFinancialSeriesResponse: Codable, Sendable {
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

enum MarketBasicFinancialMetricValue: Codable, Equatable, Sendable {
  case number(Double)
  case string(String)
  case null

  init(from decoder: Decoder) throws {
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

  func encode(to encoder: Encoder) throws {
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
