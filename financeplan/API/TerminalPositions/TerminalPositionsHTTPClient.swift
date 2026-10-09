import AnyAPI
import Foundation
import OSLog
import StockPlanShared

/// `/v1/terminal-positions` and `/v1/autobuys`.
///
/// It has its own error type instead of `StockHTTPClient.Error`, which turns
/// every 4xx with a body into `.api(message)`. The editor has to tell a Pro
/// gate (403 with `code: "upgrade_required"`) from a missing token scope (a
/// plain 403), an AI outage (503) and an unusable AI answer (422).
nonisolated struct TerminalPositionsHTTPClient: Sendable {
  enum Error: HTTPClientError {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)
    /// A status the screens tell apart, with the server's `reason`.
    case rejected(status: Int, message: String?)
    /// A 403 whose body is the billing `BillingUpgradeRequiredResponse`. Read
    /// from the body's `code`, never from the status: 403 also means a missing scope.
    case upgradeRequired(feature: String)
    /// The request was cancelled (the screen went away). Not a failure to show.
    case cancelled

    nonisolated var errorDescription: String? {
      switch self {
      case .invalidResponse: return "Invalid server response."
      case let .invalidStatus(code): return "Request failed (\(code))."
      case let .unauthorized(message): return message ?? "Your session expired. Please sign in again."
      case let .api(message): return message
      case let .rejected(status, message): return message ?? "Request failed (\(status))."
      case .upgradeRequired: return "This needs Norviq Pro."
      case .cancelled: return "The request was cancelled."
      }
    }

    nonisolated var statusCode: Int? {
      switch self {
      case let .invalidStatus(code): return code
      case let .rejected(status, _): return status
      case .upgradeRequired: return 403
      default: return nil
      }
    }

    nonisolated var isUnauthorized: Bool {
      if case .unauthorized = self { return true }
      return false
    }

    nonisolated static func == (lhs: Error, rhs: Error) -> Bool {
      switch (lhs, rhs) {
      case (.invalidResponse, .invalidResponse): return true
      case let (.invalidStatus(l), .invalidStatus(r)): return l == r
      case let (.unauthorized(l), .unauthorized(r)): return l == r
      case let (.api(l), .api(r)): return l == r
      case let (.rejected(ls, lm), .rejected(rs, rm)): return ls == rs && lm == rm
      case let (.upgradeRequired(l), .upgradeRequired(r)): return l == r
      case (.cancelled, .cancelled): return true
      default: return false
      }
    }

    static func makeInvalidResponse() -> Error { .invalidResponse }
    static func makeInvalidStatus(_ code: Int) -> Error { .invalidStatus(code) }
    static func makeUnauthorized(_ message: String?) -> Error { .unauthorized(message) }
    static func makeAPI(_ message: String) -> Error { .api(message) }

    /// Keeps cancellation recognisable instead of turning it into `.api("cancelled")`.
    static func makeTransport(_ error: Swift.Error) -> Error {
      if error is CancellationError || (error as? URLError)?.code == .cancelled { return .cancelled }
      return .api((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
    }

    static func makeStatus(_ code: Int, message: String?) -> Error {
      if [400, 403, 404, 409, 422, 429, 503].contains(code) { return .rejected(status: code, message: message) }
      if let message, !message.isEmpty { return .api(message) }
      return .invalidStatus(code)
    }

    static func makeStatus(_ code: Int, message: String?, body: Data) -> Error {
      if code == 403,
         let billing = try? JSONDecoder().decode(UpgradeRequiredBody.self, from: body),
         billing.code == "upgrade_required" {
        return .upgradeRequired(feature: billing.feature ?? "terminal_position_ai")
      }
      return makeStatus(code, message: message)
    }
  }

  /// The fields of `BillingUpgradeRequiredResponse` the client reads:
  /// `{"success":false,"code":"upgrade_required","error":…,"feature":…}`.
  nonisolated private struct UpgradeRequiredBody: Decodable {
    let code: String?
    let feature: String?
  }

  private let client: BaseHTTPClient

  init(
    baseURL: URL,
    session: any HTTPClientSession = URLSession.shared,
    authTokenProvider: @escaping @Sendable () async -> String? = { nil }
  ) {
    self.client = BaseHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: authTokenProvider,
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "TerminalPositionsHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  func list(ticker: String?) async throws -> TerminalPositionsListResponse {
    try await client.call(ListTerminalPositionsEndpoint(ticker: ticker), errorType: Error.self)
  }

  func create(_ request: TerminalPositionCreateRequest) async throws -> TerminalPositionResponse {
    try await client.call(CreateTerminalPositionEndpoint(payload: request), errorType: Error.self)
  }

  func update(id: String, _ request: TerminalPositionUpdateRequest) async throws -> TerminalPositionResponse {
    try await client.call(UpdateTerminalPositionEndpoint(id: id, payload: request), errorType: Error.self)
  }

  func delete(id: String) async throws {
    try await client.callWithoutResponse(DeleteTerminalPositionEndpoint(id: id), errorType: Error.self)
  }

  func duplicate(id: String) async throws -> TerminalPositionResponse {
    try await client.call(DuplicateTerminalPositionEndpoint(id: id), errorType: Error.self)
  }

  func reorder(ids: [String]) async throws -> TerminalPositionsListResponse {
    try await client.call(
      ReorderTerminalPositionsEndpoint(payload: TerminalPositionOrderRequest(ids: ids)),
      errorType: Error.self
    )
  }

  func summary() async throws -> TerminalPositionsSummaryResponse {
    try await client.call(TerminalPositionsSummaryEndpoint(), errorType: Error.self)
  }

  func autobuys() async throws -> AutobuysListResponse {
    try await client.call(ListAutobuysEndpoint(), errorType: Error.self)
  }

  func createAutobuy(_ request: AutobuyCreateRequest) async throws -> AutobuyResponse {
    try await client.call(CreateAutobuyEndpoint(payload: request), errorType: Error.self)
  }

  func updateAutobuy(id: String, _ request: AutobuyUpdateRequest) async throws -> AutobuyResponse {
    try await client.call(UpdateAutobuyEndpoint(id: id, payload: request), errorType: Error.self)
  }

  func deleteAutobuy(id: String) async throws {
    try await client.callWithoutResponse(DeleteAutobuyEndpoint(id: id), errorType: Error.self)
  }

  func shareFacts(ticker: String) async throws -> ShareFactsSuggestion {
    try await client.call(ShareFactsEndpoint(payload: ShareFactsRequest(ticker: ticker)), errorType: Error.self)
  }

  func suggestScenario(ticker: String, horizonYears: Int?) async throws -> TerminalScenarioSuggestion {
    try await client.call(
      TerminalScenarioSuggestionEndpoint(
        payload: TerminalScenarioSuggestionRequest(ticker: ticker, horizonYears: horizonYears)
      ),
      errorType: Error.self
    )
  }
}
