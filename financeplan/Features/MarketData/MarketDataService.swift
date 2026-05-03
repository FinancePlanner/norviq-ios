import Foundation
import StockPlanShared

protocol MarketDataServicing: Sendable {
  func fetchCompanyProfile(symbol: String) async throws -> CompanyProfileResponse
  func fetchQuote(symbol: String) async throws -> QuoteResponse
  func fetchAnalystConsensus(symbol: String) async throws -> StockAnalystConsensus
  func fetchBasicFinancials(symbol: String) async throws -> StockBasicFinancials
  func fetchAnalysisMetrics(
    symbol: String,
    wacc: Double?,
    terminalGrowthRate: Double?,
    terminalMargin: Double?,
    fcfMarginAssumption: Double?
  ) async throws -> StockAnalysisMetrics
  func fetchMarketCompare(symbols: [String]) async throws -> [StockAnalysisMetrics]
  func fetchBalanceSheetStatement(symbol: String, limit: Int?, period: String?) async throws -> [BalanceSheetStatementResponse]
  func fetchCashFlowStatement(symbol: String, limit: Int?, period: String?) async throws -> [CashFlowStatementResponse]
  func fetchRatios(symbol: String, limit: Int?, period: String?) async throws -> [RatiosResponse]
  func fetchRatiosTTM(symbol: String) async throws -> [RatiosTTMResponse]
  func fetchFinancialGrowth(symbol: String, limit: Int?, period: String?) async throws -> [FinancialGrowthResponse]
  func fetchAnalystEstimates(symbol: String, limit: Int?, period: String?) async throws -> [AnalystEstimatesResponse]
  func fetchStockEarnings(symbol: String, limit: Int) async throws -> [EarningsEvent]
  func fetchEarningsCalendar(from: String, to: String) async throws -> [EarningsEvent]
  func fetchMarketNews(limit: Int?) async throws -> [StockNews]
  func fetchFinancialStatements(symbol: String) async throws -> StockFinancialStatements
  func fetchPriceChart(symbol: String, range: String) async throws -> PriceChartSeries
  func fetchPriceChartComparison(symbols: [String], range: String) async throws -> PriceChartComparisonResponse
}

final class MarketDataHTTPService: MarketDataServicing {
  private let environmentManager: AppEnvironmentManager
  private let session: MarketDataURLSessionProtocol
  private let authSessionManager: AuthSessionManaging
  private let profileCache: CompanyProfileCaching

  init(
    environmentManager: AppEnvironmentManager,
    session: MarketDataURLSessionProtocol = URLSession.shared,
    authSessionManager: AuthSessionManaging,
    profileCache: CompanyProfileCaching = CompanyProfileCache.shared
  ) {
    self.environmentManager = environmentManager
    self.session = session
    self.authSessionManager = authSessionManager
    self.profileCache = profileCache
  }

  func fetchCompanyProfile(symbol: String) async throws -> CompanyProfileResponse {
    if let cached = profileCache.getProfile(for: symbol) {
      return cached
    }

    let profile = try await performAuthenticated { client in
      try await client.fetchCompanyProfile(symbol: symbol)
    }

    profileCache.saveProfile(profile, for: symbol)
    return profile
  }

  func fetchQuote(symbol: String) async throws -> QuoteResponse {
    try await performAuthenticated { client in
      try await client.fetchQuote(symbol: symbol)
    }
  }

  func fetchAnalystConsensus(symbol: String) async throws -> StockAnalystConsensus {
    try await performAuthenticated { client in
      try await client.fetchAnalystConsensus(symbol: symbol)
    }
  }

  func fetchBasicFinancials(symbol: String) async throws -> StockBasicFinancials {
    try await performAuthenticated { client in
      try await client.fetchBasicFinancials(symbol: symbol)
    }
  }

  func fetchAnalysisMetrics(
    symbol: String,
    wacc: Double? = nil,
    terminalGrowthRate: Double? = nil,
    terminalMargin: Double? = nil,
    fcfMarginAssumption: Double? = nil
  ) async throws -> StockAnalysisMetrics {
    try await performAuthenticated { client in
      try await client.fetchAnalysisMetrics(
        symbol: symbol,
        wacc: wacc,
        terminalGrowthRate: terminalGrowthRate,
        terminalMargin: terminalMargin,
        fcfMarginAssumption: fcfMarginAssumption
      )
    }
  }

  func fetchMarketCompare(symbols: [String]) async throws -> [StockAnalysisMetrics] {
    try await performAuthenticated { client in
      try await client.fetchMarketCompare(symbols: symbols)
    }
  }

  func fetchBalanceSheetStatement(symbol: String, limit: Int? = nil, period: String? = nil) async throws -> [BalanceSheetStatementResponse] {
    try await performAuthenticated { client in
      try await client.fetchBalanceSheetStatement(symbol: symbol, limit: limit, period: period)
    }
  }

  func fetchCashFlowStatement(symbol: String, limit: Int? = nil, period: String? = nil) async throws -> [CashFlowStatementResponse] {
    try await performAuthenticated { client in
      try await client.fetchCashFlowStatement(symbol: symbol, limit: limit, period: period)
    }
  }

  func fetchRatios(symbol: String, limit: Int? = nil, period: String? = nil) async throws -> [RatiosResponse] {
    try await performAuthenticated { client in
      try await client.fetchRatios(symbol: symbol, limit: limit, period: period)
    }
  }

  func fetchRatiosTTM(symbol: String) async throws -> [RatiosTTMResponse] {
    try await performAuthenticated { client in
      try await client.fetchRatiosTTM(symbol: symbol)
    }
  }

  func fetchFinancialGrowth(symbol: String, limit: Int? = nil, period: String? = nil) async throws -> [FinancialGrowthResponse] {
    try await performAuthenticated { client in
      try await client.fetchFinancialGrowth(symbol: symbol, limit: limit, period: period)
    }
  }

  func fetchAnalystEstimates(symbol: String, limit: Int? = nil, period: String? = nil) async throws -> [AnalystEstimatesResponse] {
    try await performAuthenticated { client in
      try await client.fetchAnalystEstimates(symbol: symbol, limit: limit, period: period)
    }
  }

  func fetchStockEarnings(symbol: String, limit: Int) async throws -> [EarningsEvent] {
    try await performAuthenticated { client in
      try await client.fetchStockEarnings(symbol: symbol, limit: limit)
    }
  }

  func fetchEarningsCalendar(from: String, to: String) async throws -> [EarningsEvent] {
    try await performAuthenticated { client in
      try await client.fetchEarningsCalendar(from: from, to: to)
    }
  }

  func fetchMarketNews(limit: Int?) async throws -> [StockNews] {
    try await performAuthenticated { client in
      try await client.fetchMarketNews(limit: limit)
    }
  }

  func fetchFinancialStatements(symbol: String) async throws -> StockFinancialStatements {
    async let balanceSheets = fetchBalanceSheetStatement(symbol: symbol, limit: 5, period: "annual")
    async let cashFlows = fetchCashFlowStatement(symbol: symbol, limit: 5, period: "annual")
    async let ratios = fetchRatios(symbol: symbol, limit: 5, period: "annual")
    async let ratiosTTM = fetchRatiosTTM(symbol: symbol)
    async let growth = fetchFinancialGrowth(symbol: symbol, limit: 5, period: "annual")
    async let estimates = fetchAnalystEstimates(symbol: symbol, limit: 5, period: "annual")

    return try await StockFinancialStatements.from(
      symbol: symbol.uppercased(),
      balanceSheets: balanceSheets,
      cashFlows: cashFlows,
      ratios: ratios,
      ratiosTTM: ratiosTTM,
      growth: growth,
      estimates: estimates
    )
  }

  func fetchPriceChart(symbol: String, range: String) async throws -> PriceChartSeries {
    try await performAuthenticated { client in
      try await client.fetchPriceChart(symbol: symbol, range: range)
    }
  }

  func fetchPriceChartComparison(symbols: [String], range: String) async throws -> PriceChartComparisonResponse {
    try await performAuthenticated { client in
      try await client.fetchPriceChartComparison(symbols: symbols, range: range)
    }
  }

  private func makeClient(forceRefresh: Bool = false) async throws -> MarketDataHTTPClient {
    let token = try await resolvedAccessToken(forceRefresh: forceRefresh)
    return MarketDataHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: session,
      authTokenProvider: { token }
    )
  }

  private func performAuthenticated<T: Sendable>(
    _ operation: (MarketDataHTTPClient) async throws -> T
  ) async throws -> T {
    do {
      let client = try await makeClient()
      return try await operation(client)
    } catch let error as MarketDataHTTPClient.Error where error.isUnauthorized {
      do {
        let client = try await makeClient(forceRefresh: true)
        return try await operation(client)
      } catch let retryError as MarketDataHTTPClient.Error where retryError.isUnauthorized {
        await authSessionManager.invalidateSession()
        throw retryError
      } catch {
        throw error
      }
    }
  }

  private func resolvedAccessToken(forceRefresh: Bool) async throws -> String {
    let token = forceRefresh
      ? try await authSessionManager.refreshAccessToken()
      : try await authSessionManager.validAccessToken()

    guard let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw AuthSessionError.notAuthenticated
    }

    return token
  }
}

struct MarketDataServiceStub: MarketDataServicing {
  func fetchCompanyProfile(symbol _: String) async throws -> CompanyProfileResponse {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchQuote(symbol _: String) async throws -> QuoteResponse {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchAnalystConsensus(symbol _: String) async throws -> StockAnalystConsensus {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchBasicFinancials(symbol _: String) async throws -> StockBasicFinancials {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchAnalysisMetrics(
    symbol _: String,
    wacc _: Double? = nil,
    terminalGrowthRate _: Double? = nil,
    terminalMargin _: Double? = nil,
    fcfMarginAssumption _: Double? = nil
  ) async throws -> StockAnalysisMetrics {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchMarketCompare(symbols _: [String]) async throws -> [StockAnalysisMetrics] {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchBalanceSheetStatement(symbol _: String, limit _: Int?, period _: String?) async throws -> [BalanceSheetStatementResponse] {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchCashFlowStatement(symbol _: String, limit _: Int?, period _: String?) async throws -> [CashFlowStatementResponse] {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchRatios(symbol _: String, limit _: Int?, period _: String?) async throws -> [RatiosResponse] {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchRatiosTTM(symbol _: String) async throws -> [RatiosTTMResponse] {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchFinancialGrowth(symbol _: String, limit _: Int?, period _: String?) async throws -> [FinancialGrowthResponse] {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchAnalystEstimates(symbol _: String, limit _: Int?, period _: String?) async throws -> [AnalystEstimatesResponse] {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchStockEarnings(symbol _: String, limit _: Int) async throws -> [EarningsEvent] {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchEarningsCalendar(from _: String, to _: String) async throws -> [EarningsEvent] {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchMarketNews(limit _: Int?) async throws -> [StockNews] {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchFinancialStatements(symbol _: String) async throws -> StockFinancialStatements {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }

  func fetchPriceChart(symbol _: String, range _: String) async throws -> PriceChartSeries {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }


  func fetchPriceChartComparison(symbols _: [String], range _: String) async throws -> PriceChartComparisonResponse {
    throw MarketDataHTTPClient.Error.invalidStatus(404)
  }
}

enum MarketDataServiceDefaults {
  static let stub: any MarketDataServicing = MarketDataServiceStub()
}

// MARK: - Company Profile Caching

protocol CompanyProfileCaching: Sendable {
  func getProfile(for symbol: String) -> CompanyProfileResponse?
  func saveProfile(_ profile: CompanyProfileResponse, for symbol: String)
}

final class CompanyProfileCache: CompanyProfileCaching {
  static let shared = CompanyProfileCache()
  
  private let store: UserDefaultsProfileStore
  private let keyPrefix = "CompanyProfileCache_"

  init(userDefaults: UserDefaults = .standard) {
    self.store = UserDefaultsProfileStore(userDefaults)
  }

  func getProfile(for symbol: String) -> CompanyProfileResponse? {
    let key = cacheKey(for: symbol)
    guard let data = store.data(forKey: key) else { return nil }
    do {
      return try JSONDecoder().decode(CompanyProfileResponse.self, from: data)
    } catch {
      // If decoding fails (e.g. model changed), clear the stale cache
      store.removeObject(forKey: key)
      return nil
    }
  }

  func saveProfile(_ profile: CompanyProfileResponse, for symbol: String) {
    let key = cacheKey(for: symbol)
    do {
      let data = try JSONEncoder().encode(profile)
      store.set(data, forKey: key)
    } catch {
      print("Failed to encode CompanyProfileResponse for caching: \(error)")
    }
  }

  func clearCache(for symbol: String) {
    store.removeObject(forKey: cacheKey(for: symbol))
  }

  func clearAllCache() {
    let keys = store.dictionaryKeys().filter { $0.hasPrefix(keyPrefix) }
    for key in keys {
      store.removeObject(forKey: key)
    }
  }

  private func cacheKey(for symbol: String) -> String {
    "\(keyPrefix)\(symbol.uppercased())"
  }
}

// Safety: this wrapper stores no mutable state of its own and only forwards to
// UserDefaults key-value APIs, which are internally synchronized by Foundation.
private struct UserDefaultsProfileStore: @unchecked Sendable {
  private let userDefaults: UserDefaults

  init(_ userDefaults: UserDefaults) {
    self.userDefaults = userDefaults
  }

  func data(forKey key: String) -> Data? {
    userDefaults.data(forKey: key)
  }

  func set(_ data: Data, forKey key: String) {
    userDefaults.set(data, forKey: key)
  }

  func removeObject(forKey key: String) {
    userDefaults.removeObject(forKey: key)
  }

  func dictionaryKeys() -> [String] {
    Array(userDefaults.dictionaryRepresentation().keys)
  }
}
