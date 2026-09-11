import AnyAPI
import Foundation
import StockPlanShared
import OSLog

// MARK: - Client

nonisolated final class BrokerHTTPClient: Sendable {
  
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

  /// Uploads broker screenshots for extraction. Returns rows to review; nothing
  /// is written to the portfolio by this call.
  func previewScreenshotImport(
    provider: String,
    portfolioListId: String?,
    images: [ScreenshotUploadImage]
  ) async throws -> ScreenshotImportPreviewResponse {
    guard !images.isEmpty else { throw Error.api("Select at least one screenshot.") }
    guard images.count <= Self.maxScreenshotImages else {
      throw Error.api("Upload at most \(Self.maxScreenshotImages) screenshots at a time.")
    }

    let request = try await makeScreenshotUploadRequest(
      provider: provider,
      portfolioListId: portfolioListId,
      images: images
    )
    let data = try await client.sendRequest(request, errorType: Error.self)
    return try decodeEnveloped(ScreenshotImportPreviewResponse.self, from: data)
  }

  /// Commits the rows the user approved. Sends JSON, not images — the
  /// extraction is not repeated, so this costs no AI call and is safe to retry.
  func commitScreenshotImport(
    _ payload: ScreenshotImportCommitRequest
  ) async throws -> CsvImportCommitResponse {
    var request = URLRequest(url: client.baseURL.appendingPathComponent("v1/brokers/import/screenshot/commit"))
    request.httpMethod = HTTPMethod.post.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let token = await client.authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    request.httpBody = try JSONEncoder().encode(payload)

    let data = try await client.sendRequest(request, errorType: Error.self)
    return try decodeEnveloped(CsvImportCommitResponse.self, from: data)
  }

  /// Mirrors `ScreenshotPortfolioImportService.maxImages` on the backend.
  static let maxScreenshotImages = 3

  private func makeScreenshotUploadRequest(
    provider: String,
    portfolioListId: String?,
    images: [ScreenshotUploadImage]
  ) async throws -> URLRequest {
    let base = client.baseURL.appendingPathComponent("v1/brokers/import/screenshot")
    var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
    var queryItems = [URLQueryItem(name: "provider", value: provider)]
    if let portfolioListId, !portfolioListId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      queryItems.append(URLQueryItem(name: "portfolioListId", value: portfolioListId))
    }
    components?.queryItems = queryItems
    guard let url = components?.url else { throw Error.invalidResponse }

    var request = URLRequest(url: url)
    request.httpMethod = HTTPMethod.post.rawValue
    if let token = await client.authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    var body = MultipartFormBody()
    body.addField(name: "provider", value: provider)
    for (index, image) in images.enumerated() {
      // Repeated "file" parts; the backend decodes them as [File].
      body.addFile(
        name: "file",
        filename: image.filename ?? "screenshot-\(index + 1).jpg",
        contentType: image.contentType,
        data: image.data
      )
    }
    request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
    request.httpBody = body.finalizedData()
    return request
  }

  /// The API sometimes wraps payloads in an envelope and sometimes does not.
  private func decodeEnveloped<T: Codable & Sendable>(_ type: T.Type, from data: Data) throws -> T {
    do {
      return try client.decoder.decode(type, from: data)
    } catch {
      if let envelope = try? client.decoder.decode(APIEnvelope<T>.self, from: data),
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
    if let token = await client.authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    var body = MultipartFormBody()
    body.addField(name: "provider", value: provider)
    body.addFile(
      name: "file",
      filename: "portfolio-import.csv",
      contentType: "text/csv",
      data: csvData
    )
    request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
    request.httpBody = body.finalizedData()
    return request
  }
}
