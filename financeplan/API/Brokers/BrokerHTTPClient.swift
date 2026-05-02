import AnyAPI
import Foundation
import StockPlanShared
import OSLog

// MARK: - Client

final class BrokerHTTPClient: BaseHTTPClient<BrokerHTTPClient.Error>, @unchecked Sendable {
  
  // MARK: - Error Type
  
  enum Error: LocalizedError, Equatable, Sendable, HTTPClientError {
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
  }

  init(baseURL: URL, session: any HTTPClientSession = URLSession.shared, authTokenProvider: @escaping () -> String? = { nil }) {
    super.init(
      baseURL: baseURL,
      session: session,
      authTokenProvider: authTokenProvider,
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "BrokerHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  // MARK: - Error Factory Overrides

  override func makeInvalidResponseError() -> Error { .invalidResponse }
  override func makeInvalidStatusError(_ code: Int) -> Error { .invalidStatus(code) }
  override func makeUnauthorizedError(_ message: String?) -> Error { .unauthorized(message) }
  override func makeAPIError(_ message: String) -> Error { .api(message) }

  // MARK: - Public API

  func getBrokers() async throws -> [BrokerConnectionResponse] {
    try await call(GetBrokersEndpoint())
  }

  func getBroker(provider: String) async throws -> BrokerConnectionResponse {
    try await call(GetBrokerEndpoint(provider: provider))
  }

  func syncIBKR() async throws -> BrokerSyncResponse {
    try await call(SyncIBKREndpoint())
  }

  func startIBKRConnect(
    redirectURI: String,
    portfolioListId: String?
  ) async throws -> BrokerConnectStartResponse {
    try await call(StartIBKRConnectEndpoint(redirectURI: redirectURI, portfolioListId: portfolioListId))
  }

  func disconnectIBKR() async throws -> BrokerConnectionResponse {
    try await call(DisconnectIBKREndpoint())
  }

  func previewCsvImport(
    provider: String,
    portfolioListId: String?,
    csvData: Data
  ) async throws -> CsvImportPreviewResponse {
    let request = try makeCSVUploadRequest(
      path: "/v1/brokers/import/csv",
      provider: provider,
      portfolioListId: portfolioListId,
      csvData: csvData
    )
    let data = try await sendRequest(request)
    do {
      return try decoder.decode(CsvImportPreviewResponse.self, from: data)
    } catch {
      if let envelope = try? decoder.decode(APIEnvelope<CsvImportPreviewResponse>.self, from: data),
         let payload = envelope.data {
        return payload
      }
      throw error
    }
  }

  func commitCsvImport(
    provider: String,
    portfolioListId: String?,
    csvData: Data
  ) async throws -> CsvImportCommitResponse {
    let request = try makeCSVUploadRequest(
      path: "/v1/brokers/import/csv/commit",
      provider: provider,
      portfolioListId: portfolioListId,
      csvData: csvData
    )
    let data = try await sendRequest(request)
    do {
      return try decoder.decode(CsvImportCommitResponse.self, from: data)
    } catch {
      if let envelope = try? decoder.decode(APIEnvelope<CsvImportCommitResponse>.self, from: data),
         let payload = envelope.data {
        return payload
      }
      throw error
    }
  }

  private func makeCSVUploadRequest(
    path: String,
    provider: String,
    portfolioListId: String?,
    csvData: Data
  ) throws -> URLRequest {
    let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let base = baseURL.appendingPathComponent(normalizedPath)

    var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
    var queryItems = [URLQueryItem(name: "provider", value: provider)]
    if let portfolioListId, !portfolioListId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      queryItems.append(URLQueryItem(name: "portfolioListId", value: portfolioListId))
    }
    components?.queryItems = queryItems
    guard let url = components?.url else {
      throw Error.invalidResponse
    }

    var request = URLRequest(url: url)
    request.httpMethod = HTTPMethod.post.rawValue
    request.setValue("text/csv", forHTTPHeaderField: "Content-Type")

    if let token = authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    request.httpBody = csvData
    return request
  }
}

