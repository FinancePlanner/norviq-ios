import AnyAPI
import Foundation
import OSLog
import StockPlanShared

/// Lightweight HTTP client for macro endpoints.
/// Follows the pattern of MarketDataHTTPClient.
struct MacroHTTPClient: Sendable {
  enum Error: HTTPClientError {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)

    nonisolated var errorDescription: String? {
      switch self {
      case .invalidResponse: return "Invalid server response."
      case let .invalidStatus(code): return "Request failed (\(code))."
      case let .unauthorized(message): return message ?? "Your session expired. Please sign in again."
      case let .api(message): return message
      }
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
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "MacroHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  func getCurrentInflation(country: String? = nil) async throws -> InflationSnapshotResponse {
    try await client.call(GetInflationCurrentEndpoint(country: country), errorType: Error.self)
  }

  func getTopMovers(country: String? = nil, focus: String? = "utilities,food,shelter") async throws -> [TopMoverDTO] {
    try await client.call(GetTopMoversEndpoint(country: country, focus: focus), errorType: Error.self)
  }

  func getSeries(country: String? = nil, series: String, from: String? = nil, to: String? = nil, limit: Int? = nil) async throws -> MacroSeriesResponse {
    try await client.call(GetInflationSeriesEndpoint(country: country, series: series, from: from, to: to, limit: limit), errorType: Error.self)
  }

  func getPersonalInflation(country: String? = nil, months: Int = 12) async throws -> PersonalInflationResponse {
    try await client.call(GetPersonalInflationEndpoint(country: country, months: months), errorType: Error.self)
  }

  func getSupportedCountries() async throws -> [SupportedCountry] {
    try await client.call(GetSupportedCountriesEndpoint(), errorType: Error.self)
  }

  func getFedWatch() async throws -> FedWatchResponse {
    try await client.call(GetFedWatchEndpoint(), errorType: Error.self)
  }

  func getItems(country: String? = nil) async throws -> MacroItemsResponse {
    try await client.call(GetMacroItemsEndpoint(country: country), errorType: Error.self)
  }

  func getItemSeries(itemId: String, country: String? = nil, limit: Int? = nil) async throws -> MacroItemSeriesResponse {
    try await client.call(GetMacroItemSeriesEndpoint(itemId: itemId, country: country, limit: limit), errorType: Error.self)
  }

  func getHousing(country: String? = nil) async throws -> HousingHubResponse {
    try await client.call(GetHousingHubEndpoint(country: country), errorType: Error.self)
  }

  func getEconomy(country: String? = nil) async throws -> EconomyHubResponse {
    try await client.call(GetEconomyHubEndpoint(country: country), errorType: Error.self)
  }

  func getPolicyWatch(country: String? = nil) async throws -> PolicyWatchResponse {
    try await client.call(GetPolicyWatchEndpoint(country: country), errorType: Error.self)
  }
}
