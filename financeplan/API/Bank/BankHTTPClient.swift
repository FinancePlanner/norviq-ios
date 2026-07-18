import AnyAPI
import Foundation
import OSLog
import StockPlanShared

final class BankHTTPClient: Sendable {
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

    var isUnauthorized: Bool {
      if case .unauthorized = self { return true }
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
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "BankHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  func createLinkSession() async throws -> BankLinkSessionResponse {
    try await client.call(CreateBankLinkSessionEndpoint(), errorType: Error.self)
  }

  func exchange(publicToken: String, institutionId: String?, institutionName: String?) async throws -> BankConnectionResponse {
    try await client.call(
      ExchangeBankConnectionEndpoint(publicToken: publicToken, institutionId: institutionId, institutionName: institutionName),
      errorType: Error.self
    )
  }

  func listConnections() async throws -> [BankConnectionResponse] {
    try await client.call(ListBankConnectionsEndpoint(), errorType: Error.self)
  }

  func disconnect(connectionId: String) async throws {
    try await client.callWithoutResponse(DisconnectBankConnectionEndpoint(connectionId: connectionId), errorType: Error.self)
  }

  func sync(connectionId: String) async throws -> BankSyncResponse {
    try await client.call(SyncBankConnectionEndpoint(connectionId: connectionId), errorType: Error.self)
  }

  func listTransactions(status: String) async throws -> [BankTransactionResponse] {
    try await client.call(ListBankTransactionsEndpoint(status: status), errorType: Error.self)
  }

  func importTransaction(transactionId: String, pillar: BudgetPillar, categoryId: String?, titleOverride: String?) async throws -> ExpenseResponse {
    try await client.call(
      ImportBankTransactionEndpoint(transactionId: transactionId, pillar: pillar, categoryId: categoryId, titleOverride: titleOverride),
      errorType: Error.self
    )
  }

  func dismiss(transactionId: String) async throws {
    try await client.callWithoutResponse(DismissBankTransactionEndpoint(transactionId: transactionId), errorType: Error.self)
  }
}
