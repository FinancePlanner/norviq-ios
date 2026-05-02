import Foundation
import OSLog
import StockPlanShared

private let stockServiceLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
  category: "StockService"
)

@MainActor
protocol StockServicing: Sendable {
  @discardableResult
  func create(stock: StockRequest, portfolioListId: String?) async throws -> StockResponse
  @discardableResult
  func bulkCreate(stocks: [StockRequest]) async throws -> BulkStockResponse
  func fetchPortfolio(portfolioListId: String?, cursor: String?, limit: Int?) async throws -> (items: [StockResponse], nextCursor: String?)
  func fetchStockDetails(stockId: String) async throws -> StockDetails
  func fetchStockInsights(symbol: String) async throws -> StockInsightsResponse
  func fetchPortfolioPerformance() async throws -> PortfolioPerformanceResponse
  func fetchPortfolioSummary() async throws -> PortfolioSummaryResponse
  func fetchPortfolioPerformance(portfolioListId: String?) async throws -> PortfolioPerformanceResponse
  func fetchPortfolioSummary(portfolioListId: String?) async throws -> PortfolioSummaryResponse
  func fetchStockHistory(symbol: String) async throws -> [StockHistory]
  func fetchStockNews(symbol: String) async throws -> [StockNews]
  func updateStock(_ stock: StockResponse, portfolioListId: String?) async throws -> StockResponse
  func delete(id: String) async throws
  func getValuation(symbol: String) async throws -> StockValuationRequest
  func createValuation(
    symbol: String,
    draft: StockValuationDraft
  ) async throws -> StockValuationRequest
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
  ) async throws -> StockValuationRequest
  func updateValuation(
    symbol: String,
    draft: StockValuationDraft
  ) async throws -> StockValuationRequest
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
  ) async throws -> StockValuationRequest
  func fetchWatchlist() async throws -> [WatchlistItemResponse]
  func fetchWatchlist(watchlistListId: String?) async throws -> [WatchlistItemResponse]
  @discardableResult
  func createWatchlistItem(
    _ request: WatchlistItemRequest,
    watchlistListId: String?
  ) async throws -> WatchlistItemResponse
  @discardableResult
  func updateWatchlistItem(
    id: String,
    request: WatchlistItemUpdateRequest,
    watchlistListId: String?
  ) async throws -> WatchlistItemResponse
  func deleteWatchlistItem(id: String) async throws
  func sellStock(id: String, request: SellStockRequest) async throws -> StockResponse
  func fetchTargets(symbol: String?) async throws -> [TargetResponse]
  @discardableResult
  func createTarget(_ request: TargetRequest) async throws -> TargetResponse
  func deleteTarget(id: String) async throws
  func fetchPortfolioLists() async throws -> [PortfolioListDTOResponse]
  func createPortfolioList(name: String) async throws -> PortfolioListDTOResponse
  func updatePortfolioList(id: String, name: String) async throws -> PortfolioListDTOResponse
  func deletePortfolioList(id: String) async throws
  func fetchWatchlistLists() async throws -> [WatchlistListDTOResponse]
  func createWatchlistList(name: String) async throws -> WatchlistListDTOResponse
  func updateWatchlistList(id: String, name: String) async throws -> WatchlistListDTOResponse
  func deleteWatchlistList(id: String) async throws
}

extension StockServicing {
  func create(stock: StockRequest) async throws -> StockResponse {
    try await create(stock: stock, portfolioListId: nil)
  }


  func fetchStockInsights(symbol _: String) async throws -> StockInsightsResponse {
    throw StockHTTPClient.Error.api("Stock insights endpoint is unavailable.")
  }

  func fetchPortfolioPerformance() async throws -> PortfolioPerformanceResponse {
    try await fetchPortfolioPerformance(portfolioListId: nil)
  }

  func fetchPortfolioSummary() async throws -> PortfolioSummaryResponse {
    try await fetchPortfolioSummary(portfolioListId: nil)
  }

  func fetchPortfolio(portfolioListId: String? = nil, cursor: String? = nil, limit: Int? = nil) async throws -> (items: [StockResponse], nextCursor: String?) {
    try await fetchPortfolio(portfolioListId: portfolioListId, cursor: cursor, limit: limit)
  }

  func updateStock(_ stock: StockResponse) async throws -> StockResponse {
    try await updateStock(stock, portfolioListId: nil)
  }

  func fetchWatchlist() async throws -> [WatchlistItemResponse] {
    try await fetchWatchlist(watchlistListId: nil)
  }

  func fetchTargets(symbol _: String? = nil) async throws -> [TargetResponse] {
    throw StockHTTPClient.Error.api("Targets endpoint is unavailable.")
  }

  @discardableResult
  func createTarget(_: TargetRequest) async throws -> TargetResponse {
    throw StockHTTPClient.Error.api("Targets endpoint is unavailable.")
  }

  func deleteTarget(id _: String) async throws {
    throw StockHTTPClient.Error.api("Targets endpoint is unavailable.")
  }

  func createWatchlistItem(_ request: WatchlistItemRequest) async throws -> WatchlistItemResponse {
    try await createWatchlistItem(request, watchlistListId: nil)
  }

  func updateWatchlistItem(
    id: String,
    request: WatchlistItemUpdateRequest
  ) async throws -> WatchlistItemResponse {
    try await updateWatchlistItem(id: id, request: request, watchlistListId: nil)
  }

  func fetchPortfolioLists() async throws -> [PortfolioListDTOResponse] {
    throw StockHTTPClient.Error.api("Portfolio lists endpoint is unavailable.")
  }

  func createPortfolioList(name _: String) async throws -> PortfolioListDTOResponse {
    throw StockHTTPClient.Error.api("Portfolio lists endpoint is unavailable.")
  }

  func updatePortfolioList(id _: String, name _: String) async throws -> PortfolioListDTOResponse {
    throw StockHTTPClient.Error.api("Portfolio lists endpoint is unavailable.")
  }

  func deletePortfolioList(id _: String) async throws {
    throw StockHTTPClient.Error.api("Portfolio lists endpoint is unavailable.")
  }

  func fetchWatchlistLists() async throws -> [WatchlistListDTOResponse] {
    throw StockHTTPClient.Error.api("Watchlist lists endpoint is unavailable.")
  }

  func createWatchlistList(name _: String) async throws -> WatchlistListDTOResponse {
    throw StockHTTPClient.Error.api("Watchlist lists endpoint is unavailable.")
  }

  func updateWatchlistList(id _: String, name _: String) async throws -> WatchlistListDTOResponse {
    throw StockHTTPClient.Error.api("Watchlist lists endpoint is unavailable.")
  }

  func deleteWatchlistList(id _: String) async throws {
    throw StockHTTPClient.Error.api("Watchlist lists endpoint is unavailable.")
  }
}

final class StockService: StockServicing {
  private let environmentManager: AppEnvironmentManager
  private let session: StockURLSessionProtocol
  private let authSessionManager: AuthSessionManaging

  init(
    environmentManager: AppEnvironmentManager,
    session: StockURLSessionProtocol = URLSession.shared,
    authSessionManager: AuthSessionManaging
  ) {
    self.environmentManager = environmentManager
    self.session = session
    self.authSessionManager = authSessionManager
  }

  @discardableResult
  func create(stock: StockRequest, portfolioListId: String? = nil) async throws -> StockResponse {
    try await performAuthenticated { client in
      let endpoint = CreateStockEndpoint(
        symbol: stock.symbol,
        shares: stock.shares,
        buyPrice: stock.buyPrice,
        buyDate: stock.buyDate,
        notes: stock.notes,
        category: stock.category,
        portfolioListId: portfolioListId
      )
      return try await client.call(endpoint)
    }
  }

  @discardableResult
  func bulkCreate(stocks: [StockRequest]) async throws -> BulkStockResponse {
    try await performAuthenticated { client in
      let endpoint = BulkCreateStocksEndpoint(stocks: stocks)
      return try await client.call(endpoint)
    }
  }

  func fetchPortfolio(portfolioListId: String? = nil, cursor: String? = nil, limit: Int? = nil) async throws -> (items: [StockResponse], nextCursor: String?) {
    try await performAuthenticated { client in
      let endpoint = GetStocksEndpoint(portfolioListId: portfolioListId, cursor: cursor, limit: limit)
      let (items, response) = try await client.callWithHeaders(endpoint)
      let nextCursor = response.value(forHTTPHeaderField: "X-Next-Cursor")
      return (items, nextCursor)
    }
  }

  func fetchWatchlist(watchlistListId: String? = nil) async throws -> [WatchlistItemResponse] {
    try await performAuthenticated { client in
      return try await client.call(GetWatchlistEndpoint(watchlistListId: watchlistListId))
    }
  }

  func fetchStockDetails(stockId: String) async throws -> StockDetails {
    try await performAuthenticated { client in
      let endpoint = GetStockDetailsEndpoint(stockId: stockId)
      return try await client.call(endpoint)
    }
  }

  func fetchStockInsights(symbol: String) async throws -> StockInsightsResponse {
    try await performAuthenticated { client in
      let endpoint = GetStockInsightsEndpoint(symbol: symbol)
      return try await client.call(endpoint)
    }
  }

  func fetchPortfolioPerformance(portfolioListId: String? = nil) async throws -> PortfolioPerformanceResponse {
    try await performAuthenticated { client in
      return try await client.call(GetPortfolioPerformanceEndpoint(portfolioListId: portfolioListId))
    }
  }

  func fetchPortfolioSummary(portfolioListId: String? = nil) async throws -> PortfolioSummaryResponse {
    try await performAuthenticated { client in
      return try await client.call(GetPortfolioSummaryEndpoint(portfolioListId: portfolioListId))
    }
  }

  func fetchStockHistory(symbol: String) async throws -> [StockHistory] {
    try await performAuthenticated { client in
      let endpoint = GetStockHistoryEndpoint(symbol: symbol)
      return try await client.call(endpoint)
    }
  }

  func fetchStockNews(symbol: String) async throws -> [StockNews] {
    try await performAuthenticated { client in
      let endpoint = GetStockNewsEndpoint(symbol: symbol)
      return try await client.call(endpoint)
    }
  }

  func updateStock(_ stock: StockResponse, portfolioListId: String? = nil) async throws -> StockResponse {
    try await performAuthenticated { client in
      let request = StockRequest(
        symbol: stock.symbol,
        shares: stock.shares,
        buyPrice: stock.buyPrice,
        buyDate: stock.buyDate,
        notes: stock.notes ?? "",
        category: stock.category
      )
      let endpoint = UpdateStockEndpoint(
        stockId: stock.id,
        payload: request,
        portfolioListId: portfolioListId
      )
      return try await client.call(endpoint)
    }
  }

  func delete(id: String) async throws {
    try await performAuthenticated { client in
      let endpoint = DeleteStockEndpoint(stockId: id)
      try await client.callWithoutResponse(endpoint)
    }
  }

  @discardableResult
  func createWatchlistItem(
    _ request: WatchlistItemRequest,
    watchlistListId: String? = nil
  ) async throws -> WatchlistItemResponse {
    try await performAuthenticated { client in
      try await client.call(
        CreateWatchlistEndpoint(payload: request, watchlistListId: watchlistListId)
      )
    }
  }

  @discardableResult
  func updateWatchlistItem(
    id: String,
    request: WatchlistItemUpdateRequest,
    watchlistListId: String? = nil
  ) async throws -> WatchlistItemResponse {
    try await performAuthenticated { client in
      try await client.call(
        UpdateWatchlistEndpoint(
          watchlistId: id,
          payload: request,
          watchlistListId: watchlistListId
        )
      )
    }
  }

  func deleteWatchlistItem(id: String) async throws {
    try await performAuthenticated { client in
      try await client.callWithoutResponse(DeleteWatchlistEndpoint(watchlistId: id))
    }
  }

  func fetchTargets(symbol: String? = nil) async throws -> [TargetResponse] {
    try await performAuthenticated { client in
      try await client.call(GetTargetsEndpoint(symbol: symbol))
    }
  }

  @discardableResult
  func createTarget(_ request: TargetRequest) async throws -> TargetResponse {
    try await performAuthenticated { client in
      try await client.call(CreateTargetEndpoint(payload: request))
    }
  }

  func deleteTarget(id: String) async throws {
    try await performAuthenticated { client in
      try await client.callWithoutResponse(DeleteTargetEndpoint(targetId: id))
    }
  }

  func sellStock(id: String, request: SellStockRequest) async throws -> StockResponse {
    try await performAuthenticated { client in
      let endpoint = SellStockEndpoint(stockId: id, payload: request)
      return try await client.call(endpoint)
    }
  }

  func fetchPortfolioLists() async throws -> [PortfolioListDTOResponse] {
    try await performAuthenticated { client in
      try await client.call(GetPortfolioListsEndpoint())
    }
  }

  func createPortfolioList(name: String) async throws -> PortfolioListDTOResponse {
    try await performAuthenticated { client in
      try await client.call(CreatePortfolioListEndpoint(payload: PortfolioListDTORequest(name: name)))
    }
  }

  func updatePortfolioList(id: String, name: String) async throws -> PortfolioListDTOResponse {
    try await performAuthenticated { client in
      try await client.call(
        UpdatePortfolioListEndpoint(listId: id, payload: PortfolioListDTORequest(name: name))
      )
    }
  }

  func deletePortfolioList(id: String) async throws {
    try await performAuthenticated { client in
      try await client.callWithoutResponse(DeletePortfolioListEndpoint(listId: id))
    }
  }

  func fetchWatchlistLists() async throws -> [WatchlistListDTOResponse] {
    try await performAuthenticated { client in
      try await client.call(GetWatchlistListsEndpoint())
    }
  }

  func createWatchlistList(name: String) async throws -> WatchlistListDTOResponse {
    try await performAuthenticated { client in
      try await client.call(CreateWatchlistListEndpoint(payload: WatchlistListDTORequest(name: name)))
    }
  }

  func updateWatchlistList(id: String, name: String) async throws -> WatchlistListDTOResponse {
    try await performAuthenticated { client in
      try await client.call(
        UpdateWatchlistListEndpoint(listId: id, payload: WatchlistListDTORequest(name: name))
      )
    }
  }

  func deleteWatchlistList(id: String) async throws {
    try await performAuthenticated { client in
      try await client.callWithoutResponse(DeleteWatchlistListEndpoint(listId: id))
    }
  }

  func getValuation(symbol: String) async throws -> StockValuationRequest {
    try await performAuthenticated { client in
      let endpoint = GetStockValuationEndpoint(symbol: symbol)
      return try await client.call(endpoint)
    }
  }

  func createValuation(
    symbol: String,
    draft: StockValuationDraft
  ) async throws -> StockValuationRequest {
    stockServiceLogger.debug(
      "Create valuation symbol=\(symbol, privacy: .public)"
    )
    return try await performAuthenticated { client in
      let endpoint = try CreateStockValuationEndpoint(
        symbol: symbol,
        draft: draft
      )
      return try await client.call(endpoint)
    }
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
    try await createValuation(
      symbol: symbol,
      draft: StockValuationDraft(
        bearLow: bearLow,
        bearHigh: bearHigh,
        baseLow: baseLow,
        baseHigh: baseHigh,
        bullLow: bullLow,
        bullHigh: bullHigh,
        rationale: rationale,
        targetDate: targetDate
      )
    )
  }

  func updateValuation(
    symbol: String,
    draft: StockValuationDraft
  ) async throws -> StockValuationRequest {
    stockServiceLogger.debug(
      "Update valuation symbol=\(symbol, privacy: .public)"
    )
    return try await performAuthenticated { client in
      let endpoint = try UpdateStockValuationEndpoint(
        symbol: symbol,
        draft: draft
      )
      return try await client.call(endpoint)
    }
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
    try await updateValuation(
      symbol: symbol,
      draft: StockValuationDraft(
        bearLow: bearLow,
        bearHigh: bearHigh,
        baseLow: baseLow,
        baseHigh: baseHigh,
        bullLow: bullLow,
        bullHigh: bullHigh,
        rationale: rationale,
        targetDate: targetDate
      )
    )
  }

  private func makeClient(forceRefresh: Bool = false) async throws -> StockHTTPClient {
    let token = try await resolvedAccessToken(forceRefresh: forceRefresh)
    return StockHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: session,
      authTokenProvider: { token }
    )
  }

  private func performAuthenticated<T>(
    _ operation: (StockHTTPClient) async throws -> T
  ) async throws -> T {
    do {
      let client = try await makeClient()
      return try await operation(client)
    } catch let error as StockHTTPClient.Error where error.isUnauthorized {
      let refreshedClient = try await makeClient(forceRefresh: true)

      do {
        return try await operation(refreshedClient)
      } catch let retryError as StockHTTPClient.Error where retryError.isUnauthorized {
        await authSessionManager.invalidateSession()
        throw retryError
      }
    }
  }

  private func resolvedAccessToken(forceRefresh: Bool = false) async throws -> String {
    if forceRefresh {
      guard let token = try await authSessionManager.refreshAccessToken(),
            !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw AuthSessionError.notAuthenticated
      }
      return token
    } else {
      guard let token = try await authSessionManager.validAccessToken(),
            !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw AuthSessionError.notAuthenticated
      }
      return token
    }
  }
}
