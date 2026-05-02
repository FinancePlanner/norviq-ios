import AnyAPI
import Foundation
import StockPlanShared
import OSLog

protocol StockURLSessionProtocol: HTTPClientSession {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: StockURLSessionProtocol {}

// MARK: - Client

struct StockHTTPClient: Sendable {
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
  private let logger: Logger

  init(baseURL: URL, session: any HTTPClientSession = URLSession.shared, authTokenProvider: @escaping @Sendable () -> String? = { nil }) {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "StockHTTPClient")
    self.logger = logger
    self.client = BaseHTTPClient(
        baseURL: baseURL,
        session: session,
        authTokenProvider: authTokenProvider,
        requestLogger: { path, method, parameters in
            StockHTTPClient.logValuationRequestIfNeeded(logger: logger, path: path, method: method, parameters: parameters)
        },
        logger: logger,
        decoder: .stockPlanShared
    )
  }

  func call<E: Endpoint>(_ endpoint: E) async throws -> E.Response where E.Response: Codable & Sendable {
    try await client.call(endpoint, errorType: Error.self)
  }

  func callWithoutResponse<E: Endpoint>(_ endpoint: E) async throws where E.Response: Codable {
    try await client.callWithoutResponse(endpoint, errorType: Error.self)
  }

  func callWithHeaders<E: Endpoint>(_ endpoint: E) async throws -> (response: E.Response, headers: HTTPURLResponse) where E.Response: Codable & Sendable {
    try await client.callWithHeaders(endpoint, errorType: Error.self)
  }

  // MARK: - Legacy / Special Methods
  
  func execute<E: Endpoint>(_ endpoint: E) async throws -> Data where E.Response: Codable {
    try await client.execute(endpoint, errorType: Error.self)
  }

  nonisolated private static func logValuationRequestIfNeeded(logger: Logger, path: String, method: HTTPMethod, parameters: Parameters) {
    guard path.contains("/stocks/symbol/"), path.contains("/valuation") else {
      return
    }

    let payloadDescription: String
    if let data = try? JSONSerialization.data(withJSONObject: parameters, options: [.sortedKeys]),
       let json = String(data: data, encoding: .utf8) {
        payloadDescription = json
    } else {
        payloadDescription = "\(parameters)"
    }

    logger.debug(
      "Stock request [\(path, privacy: .public)] method=\(method.rawValue, privacy: .public) body=\(payloadDescription, privacy: .public)"
    )
  }
}
