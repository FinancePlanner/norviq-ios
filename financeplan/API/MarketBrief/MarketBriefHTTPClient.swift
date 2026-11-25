import AnyAPI
import Foundation
import OSLog
import StockPlanShared

/// `/v1/market/brief` and its notification preferences.
nonisolated struct MarketBriefHTTPClient: Sendable {
  enum Error: HTTPClientError {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)

    nonisolated var errorDescription: String? {
      switch self {
      case .invalidResponse: return "Invalid server response."
      case let .invalidStatus(code): return "Request failed (\(code))."
      case let .unauthorized(message): return message ?? "Your session expired."
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

    /// 404 (superseded edition), 500 and 503 (renderer busy) drive the studio's
    /// retry and fallback, so they keep their code even when the body has a message.
    static func makeStatus(_ code: Int, message: String?) -> Error {
      if [404, 500, 503].contains(code) { return .invalidStatus(code) }
      if let message, !message.isEmpty { return .api(message) }
      return .invalidStatus(code)
    }

    static func makeInvalidResponse() -> Error { .invalidResponse }
    static func makeInvalidStatus(_ code: Int) -> Error { .invalidStatus(code) }
    static func makeUnauthorized(_ message: String?) -> Error { .unauthorized(message) }
    static func makeAPI(_ message: String) -> Error { .api(message) }
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
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "MarketBriefHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  func brief(lang: String, slot: MarketBriefSlot?, date: String?) async throws -> MarketBriefResponse {
    try await client.call(GetMarketBriefEndpoint(lang: lang, slot: slot, date: date), errorType: Error.self)
  }

  func notificationPreferences() async throws -> MarketBriefNotificationPreferences {
    try await client.call(GetMarketBriefNotificationsEndpoint(), errorType: Error.self)
  }

  func updateNotificationPreferences(enabled: Bool, language: String) async throws -> MarketBriefNotificationPreferences {
    try await client.call(
      UpdateMarketBriefNotificationsEndpoint(enabled: enabled, language: language),
      errorType: Error.self
    )
  }

  // MARK: Export Studio

  func exports(lang: String, slot: MarketBriefSlot, date: String) async throws -> MarketBriefExportManifest {
    try await client.call(GetMarketBriefExportsEndpoint(lang: lang, slot: slot, date: date), errorType: Error.self)
  }

  /// One attempt, no client-side retry: the studio owns the 503/500 and 404 policy.
  func exportFile(
    lang: String,
    slot: MarketBriefSlot,
    date: String,
    format: MarketBriefExportFormat,
    query: String
  ) async throws -> MarketBriefExportFile {
    let endpoint = GetMarketBriefExportFileEndpoint(lang: lang, slot: slot, date: date, format: format, query: query)
    var request = try await client.makeURLRequest(for: endpoint)
    request.timeoutInterval = GetMarketBriefExportFileEndpoint.timeout
    let data: Data
    let response: HTTPURLResponse
    do {
      (data, response) = try await client.sendRequestWithResponse(request, errorType: Error.self)
    } catch {
      throw client.makeError(from: error, to: Error.self)
    }
    let fileName = Self.fileName(from: response)
      ?? "norviq-brief-\(date)-\(slot.rawValue)-\(format.rawValue)-\(lang).\(format.fileExtension)"
    let mime = response.value(forHTTPHeaderField: "Content-Type")?
      .split(separator: ";").first.map { $0.trimmingCharacters(in: .whitespaces) }
      ?? format.mime
    return MarketBriefExportFile(data: data, fileName: fileName, mime: mime)
  }

  /// `inline; filename="norviq-MI-2026-11-25-O-social-en.png"`. The name ends up in a
  /// file path, so anything that is not a plain file name is rejected.
  static func fileName(from response: HTTPURLResponse) -> String? {
    guard let header = response.value(forHTTPHeaderField: "Content-Disposition"),
          let match = header.range(of: #"filename="([^"]+)""#, options: .regularExpression)
    else { return nil }
    let name = String(header[match]).dropFirst("filename=\"".count).dropLast()
    let value = String(name)
    guard !value.isEmpty, value != ".", value != "..",
          !value.contains("/"), !value.contains("\\")
    else { return nil }
    return value
  }
}
