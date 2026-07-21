import AnyAPI
import Foundation
import StockPlanShared
import OSLog

// MARK: - Client

final class BrokerHTTPClient: Sendable {
  
  // MARK: - Error Type
  
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

  init(baseURL: URL, session: any HTTPClientSession = URLSession.shared, authTokenProvider: @escaping @Sendable () async -> String? = { nil }) {
    self.client = BaseHTTPClient(
        baseURL: baseURL,
        session: session,
        authTokenProvider: authTokenProvider,
        logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "BrokerHTTPClient"),
        decoder: .stockPlanShared
    )
  }

  // MARK: - Public API (delegated)

  func getBrokers() async throws -> [BrokerConnectionResponse] {
    try await client.call(GetBrokersEndpoint(), errorType: Error.self)
  }

  func getBroker(provider: String) async throws -> BrokerConnectionResponse {
    try await client.call(GetBrokerEndpoint(provider: provider), errorType: Error.self)
  }

  func syncIBKR() async throws -> BrokerSyncResponse {
    try await client.call(SyncIBKREndpoint(), errorType: Error.self)
  }

  func startIBKRConnect(
    redirectURI: String,
    portfolioListId: String?
  ) async throws -> BrokerConnectStartResponse {
    try await client.call(StartIBKRConnectEndpoint(redirectURI: redirectURI, portfolioListId: portfolioListId), errorType: Error.self)
  }

  func connectIBKRCredentials(
    token: String,
    queryId: String,
    portfolioListId: String?
  ) async throws -> BrokerConnectionResponse {
    try await client.call(
      ConnectIBKRCredentialsEndpoint(token: token, queryId: queryId, portfolioListId: portfolioListId),
      errorType: Error.self
    )
  }

  func disconnectIBKR() async throws -> BrokerConnectionResponse {
    try await client.call(DisconnectIBKREndpoint(), errorType: Error.self)
  }

  func previewCsvImport(
    provider: String,
    portfolioListId: String?,
    csvData: Data
  ) async throws -> CsvImportPreviewResponse {
    let request = try await makeCSVUploadRequest(
      path: "/v1/brokers/import/csv",
      provider: provider,
      portfolioListId: portfolioListId,
      csvData: csvData
    )
    let data = try await client.sendRequest(request, errorType: Error.self)
    do {
      return try client.decoder.decode(CsvImportPreviewResponse.self, from: data)
    } catch {
      if let envelope = try? client.decoder.decode(APIEnvelope<CsvImportPreviewResponse>.self, from: data),
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
    let request = try await makeCSVUploadRequest(
      path: "/v1/brokers/import/csv/commit",
      provider: provider,
      portfolioListId: portfolioListId,
      csvData: csvData
    )
    let data = try await client.sendRequest(request, errorType: Error.self)
    do {
      return try client.decoder.decode(CsvImportCommitResponse.self, from: data)
    } catch {
      if let envelope = try? client.decoder.decode(APIEnvelope<CsvImportCommitResponse>.self, from: data),
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
  ) async throws -> URLRequest {
    let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let base = client.baseURL.appendingPathComponent(normalizedPath)

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
    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    if let token = await client.authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    request.httpBody = makeCSVUploadBody(
      boundary: boundary,
      provider: provider,
      csvData: csvData,
      filename: "portfolio-import.csv"
    )
    return request
  }

  private func makeCSVUploadBody(
    boundary: String,
    provider: String,
    csvData: Data,
    filename: String
  ) -> Data {
    let newline = "\r\n"
    var body = Data()

    func append(_ text: String) {
      body.append(Data(text.utf8))
    }

    append("--\(boundary)\(newline)")
    append("Content-Disposition: form-data; name=\"provider\"\(newline)\(newline)")
    append("\(provider)\(newline)")
    append("--\(boundary)\(newline)")
    append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\(newline)")
    append("Content-Type: text/csv\(newline)\(newline)")
    body.append(csvData)
    append(newline)
    append("--\(boundary)--\(newline)")

    return body
  }
}
