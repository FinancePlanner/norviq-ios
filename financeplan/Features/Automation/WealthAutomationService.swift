import Foundation
import StockPlanShared

@MainActor
protocol WealthAutomationServicing: Sendable {
  func portfolioLists() async throws -> [AutomationListOption]
  func watchlistLists() async throws -> [AutomationListOption]
  func forecasts() async throws -> [ForecastDefinitionWire]
  func forecastDefaults() async throws -> ForecastDefaultsWire
  func createForecast(portfolioID: String, request: ForecastUpsertWire) async throws -> ForecastDefinitionWire
  func runForecast(id: String) async throws -> ForecastRunWire
  func screens() async throws -> [WatchlistScreenWire]
  func screenCatalog() async throws -> [ScreenMetricWire]
  func createScreen(_ request: WatchlistScreenUpsertWire) async throws -> WatchlistScreenWire
  func evaluateScreen(id: String) async throws -> ScreenEvaluationWire
  func rebalancingPolicy(portfolioID: String) async throws -> RebalancingPolicyWire?
  func saveRebalancingPolicy(portfolioID: String, request: RebalancingPolicyUpsertWire) async throws -> RebalancingPolicyWire
  func previewRebalancing(portfolioID: String) async throws -> RebalancePreviewWire
  func notifications() async throws -> NotificationPageWire
  func markNotificationRead(id: String) async throws
  func markAllNotificationsRead() async throws
}

@MainActor
final class WealthAutomationService: WealthAutomationServicing {
  enum ServiceError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case requestFailed(Int, String?)

    var errorDescription: String? {
      switch self {
      case .notAuthenticated: "Sign in to continue."
      case .invalidResponse: "The server returned an invalid response."
      case let .requestFailed(code, message): message ?? "Request failed (\(code))."
      }
    }
  }

  private let environmentManager: AppEnvironmentManager
  private let authSessionManager: AuthSessionManaging
  private let session: URLSession
  private let decoder: JSONDecoder
  private let encoder: JSONEncoder

  init(
    environmentManager: AppEnvironmentManager,
    authSessionManager: AuthSessionManaging,
    session: URLSession = .shared
  ) {
    self.environmentManager = environmentManager
    self.authSessionManager = authSessionManager
    self.session = session
    decoder = .stockPlanShared
    encoder = .stockPlanShared
  }

  func portfolioLists() async throws -> [AutomationListOption] {
    try await get("/v1/portfolio/lists")
  }

  func watchlistLists() async throws -> [AutomationListOption] {
    try await get("/v1/watchlist/lists")
  }

  func forecasts() async throws -> [ForecastDefinitionWire] {
    try await get("/v1/net-worth-forecasts")
  }

  func forecastDefaults() async throws -> ForecastDefaultsWire {
    try await get("/v1/net-worth-forecasts/defaults")
  }

  func createForecast(portfolioID: String, request: ForecastUpsertWire) async throws -> ForecastDefinitionWire {
    try await send(
      "/v1/net-worth-forecasts",
      method: "POST",
      query: [URLQueryItem(name: "portfolio_list_id", value: portfolioID)],
      body: request
    )
  }

  func runForecast(id: String) async throws -> ForecastRunWire {
    try await send("/v1/net-worth-forecasts/\(id)/runs", method: "POST", body: EmptyAutomationBody())
  }

  func screens() async throws -> [WatchlistScreenWire] {
    try await get("/v1/watchlist/screens")
  }

  func screenCatalog() async throws -> [ScreenMetricWire] {
    try await get("/v1/watchlist/screens/catalog")
  }

  func createScreen(_ request: WatchlistScreenUpsertWire) async throws -> WatchlistScreenWire {
    try await send(
      "/v1/watchlist/screens",
      method: "POST",
      body: request
    ) }

  func evaluateScreen(id: String) async throws -> ScreenEvaluationWire {
    try await send(
      "/v1/watchlist/screens/\(id)/evaluate",
      method: "POST",
      body: EmptyAutomationBody()
    ) }

  func rebalancingPolicy(portfolioID: String) async throws -> RebalancingPolicyWire? {
    do { return try await get("/v1/portfolio/lists/\(portfolioID)/rebalancing-policy") }
    catch ServiceError.requestFailed(404, _) { return nil }
  }

  func saveRebalancingPolicy(portfolioID: String, request: RebalancingPolicyUpsertWire) async throws -> RebalancingPolicyWire {
    try await send("/v1/portfolio/lists/\(portfolioID)/rebalancing-policy", method: "PUT", body: request)
  }

  func previewRebalancing(portfolioID: String) async throws -> RebalancePreviewWire {
    try await get(
      "/v1/portfolio/lists/\(portfolioID)/rebalancing-policy/preview"
    ) }

  func notifications() async throws -> NotificationPageWire {
    try await get("/v1/notifications/inbox")
  }

  func markNotificationRead(id: String) async throws {
    let _: NotificationItemWire = try await send(
      "/v1/notifications/inbox/\(id)",
      method: "PATCH",
      body: NotificationReadWire(read: true)
    )
  }

  func markAllNotificationsRead() async throws {
    try await sendWithoutResponse("/v1/notifications/inbox/read-all", method: "POST")
  }

  private func get<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
    try await request(
      path: path,
      method: "GET",
      query: [],
      body: EmptyAutomationBody?.none,
      response: Response.self,
      forceRefresh: false
    )
  }

  private func send<Response: Decodable & Sendable>(
    _ path: String,
    method: String,
    query: [URLQueryItem] = [],
    body: some Encodable & Sendable
  )
    async throws -> Response
  {
    try await request(path: path, method: method, query: query, body: body, response: Response.self, forceRefresh: false)
  }

  private func sendWithoutResponse(_ path: String, method: String) async throws {
    let token = try await accessToken(forceRefresh: false)
    var request = try makeRequest(path: path, method: method, query: [], token: token)
    request.httpBody = nil
    let (_, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
    guard (200..<300).contains(http.statusCode) else { throw ServiceError.requestFailed(http.statusCode, nil) }
  }

  private func request<Response: Decodable & Sendable>(
    path: String,
    method: String,
    query: [URLQueryItem],
    body: (some Encodable & Sendable)?,
    response: Response.Type,
    forceRefresh: Bool
  )
    async throws -> Response
  {
    let token = try await accessToken(forceRefresh: forceRefresh)
    var urlRequest = try makeRequest(path: path, method: method, query: query, token: token)
    if let body {
      urlRequest.httpBody = try encoder.encode(body)
    }
    let (data, urlResponse) = try await session.data(for: urlRequest)
    guard let http = urlResponse as? HTTPURLResponse else { throw ServiceError.invalidResponse }
    if http.statusCode == 401, !forceRefresh {
      return try await request(
        path: path,
        method: method,
        query: query,
        body: body,
        response: response,
        forceRefresh: true
      )
    }
    guard (200..<300).contains(http.statusCode) else {
      let message = (try? decoder.decode(APIErrorResponse.self, from: data))?.error
      if http.statusCode == 401 {
        await authSessionManager.invalidateSession()
      }
      throw ServiceError.requestFailed(http.statusCode, message)
    }
    return try decoder.decode(Response.self, from: data)
  }

  private func accessToken(forceRefresh: Bool) async throws -> String {
    let token = forceRefresh
      ? try await authSessionManager.refreshAccessToken()
      : try await authSessionManager.validAccessToken()
    guard let token else { throw ServiceError.notAuthenticated }
    return token
  }

  private func makeRequest(path: String, method: String, query: [URLQueryItem], token: String) throws -> URLRequest {
    guard
      var components = URLComponents(
        url: environmentManager.current.apiBaseUrl.appending(path: path),
        resolvingAgainstBaseURL: false
      )
    else {
      throw ServiceError.invalidResponse
    }
    components.queryItems = query.isEmpty ? nil : query
    guard let url = components.url else { throw ServiceError.invalidResponse }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    return request
  }
}
