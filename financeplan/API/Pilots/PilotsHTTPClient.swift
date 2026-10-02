import AnyAPI
import Foundation
import OSLog
import StockPlanShared

nonisolated struct PilotsHTTPClient: Sendable {
  enum Error: HTTPClientError {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)
    /// A 4xx the pilots UI must tell apart, with the server's reason:
    /// 400 bad capital, 403 upgrade or token scope, 404 missing or feature off,
    /// 409 no trades yet or duplicate follow, 422 target not empty.
    case rejected(status: Int, message: String?)
    /// A 403 whose body is the billing `BillingUpgradeRequiredResponse`
    /// (`code: "upgrade_required"`). `feature` is the plan feature that hit
    /// its limit, e.g. `pilot_follows` or `portfolio_lists`. Read from the
    /// structured body, never from the reason text.
    /// `limit` and `current` are the body's counts, when it sends them.
    case upgradeRequired(feature: String, message: String?, limit: Int? = nil, current: Int? = nil)
    /// The request was cancelled (the screen went away). Not a failure to show.
    case cancelled

    nonisolated var errorDescription: String? {
      switch self {
      case .invalidResponse: return "Invalid server response."
      case let .invalidStatus(code): return "Request failed (\(code))."
      case let .unauthorized(message): return message ?? "Your session expired. Please sign in again."
      case let .api(message): return message
      case let .rejected(status, message): return message ?? "Request failed (\(status))."
      // The server's text ("Upgrade required. feature=… plan=…") is for logs.
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

    nonisolated static func == (lhs: Error, rhs: Error) -> Bool {
      switch (lhs, rhs) {
      case (.invalidResponse, .invalidResponse): return true
      case let (.invalidStatus(l), .invalidStatus(r)): return l == r
      case let (.unauthorized(l), .unauthorized(r)): return l == r
      case let (.api(l), .api(r)): return l == r
      case let (.rejected(ls, lm), .rejected(rs, rm)): return ls == rs && lm == rm
      case let (.upgradeRequired(lf, lm, ll, lc), .upgradeRequired(rf, rm, rl, rc)):
        return lf == rf && lm == rm && ll == rl && lc == rc
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
      if [400, 403, 404, 409, 422].contains(code) { return .rejected(status: code, message: message) }
      if let message, !message.isEmpty { return .api(message) }
      return .invalidStatus(code)
    }

    static func makeStatus(_ code: Int, message: String?, body: Data) -> Error {
      if code == 403,
         let billing = try? JSONDecoder().decode(UpgradeRequiredBody.self, from: body),
         billing.code == "upgrade_required",
         let feature = billing.feature, !feature.isEmpty {
        return .upgradeRequired(feature: feature, message: message, limit: billing.limit, current: billing.current)
      }
      return makeStatus(code, message: message)
    }
  }

  /// The fields of the backend's `BillingUpgradeRequiredResponse` the client
  /// needs: `{"success":false,"code":"upgrade_required","error":…,"feature":…}`.
  nonisolated private struct UpgradeRequiredBody: Decodable {
    let code: String?
    let feature: String?
    let limit: Int?
    let current: Int?
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
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "PilotsHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  func pilots() async throws -> [PilotSummary] {
    try await client.call(ListPilotsEndpoint(), errorType: Error.self)
  }

  func pilot(slug: String) async throws -> PilotDetail {
    try await client.call(GetPilotEndpoint(slug: slug), errorType: Error.self)
  }

  func follows() async throws -> [PilotFollowResponse] {
    try await client.call(ListPilotFollowsEndpoint(), errorType: Error.self)
  }

  func follow(_ request: PilotFollowCreateRequest, idempotencyKey: String) async throws -> PilotFollowResponse {
    try await client.call(CreatePilotFollowEndpoint(payload: request, idempotencyKey: idempotencyKey), errorType: Error.self)
  }

  func setStatus(_ status: PilotFollowStatus, followId: String) async throws -> PilotFollowResponse {
    try await client.call(
      UpdatePilotFollowEndpoint(followId: followId, payload: PilotFollowUpdateRequest(status: status)),
      errorType: Error.self
    )
  }

  func stopFollowing(followId: String) async throws {
    try await client.callWithoutResponse(DeletePilotFollowEndpoint(followId: followId), errorType: Error.self)
  }

  func events(followId: String) async throws -> [PilotFollowEventResponse] {
    try await client.call(ListPilotFollowEventsEndpoint(followId: followId), errorType: Error.self)
  }

  func snapshots(followId: String) async throws -> [PilotFollowSnapshotResponse] {
    try await client.call(ListPilotFollowSnapshotsEndpoint(followId: followId), errorType: Error.self)
  }
}
