import AnyAPI
import Foundation
import OSLog
import StockPlanShared

/// Uploads receipt photos to the backend OCR endpoint. Mirrors the multipart
/// upload approach in `BrokerHTTPClient` (the `Endpoint`/`Parameters` abstraction
/// in `BaseHTTPClient` is for JSON bodies, not binary), while reusing its auth
/// token provider and JSON decoder.
nonisolated final class ReceiptsHTTPClient: Sendable {

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

  init(
    baseURL: URL,
    session: any HTTPClientSession = URLSession.shared,
    authTokenProvider: @escaping @Sendable () async -> String? = { nil }
  ) {
    self.client = BaseHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: authTokenProvider,
      logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "ReceiptsHTTPClient"),
      decoder: .stockPlanShared
    )
  }

  /// Uploads a receipt image to `/v1/receipts/ocr` and returns the extracted
  /// draft. `recognized` is false when nothing usable was read. Throws when OCR
  /// is unavailable (backend 503) or the user is not entitled (Pro-gated).
  func ocr(imageData: Data, contentType: String, filename: String = "receipt.jpg") async throws -> ReceiptDraftResponse {
    let request = try await makeUploadRequest(imageData: imageData, contentType: contentType, filename: filename)
    let data = try await client.sendRequest(request, errorType: Error.self)
    do {
      return try client.decoder.decode(ReceiptDraftResponse.self, from: data)
    } catch {
      if let envelope = try? client.decoder.decode(APIEnvelope<ReceiptDraftResponse>.self, from: data),
         let payload = envelope.data {
        return payload
      }
      throw error
    }
  }

  /// Mirrors the backend's per-request ceiling on `/v1/receipts/scan`.
  static let maxBatchImages = 5

  /// Scans several receipt photos in one request.
  ///
  /// Results come back in the order the images were sent, so a caller can pair
  /// a failure with its photo. An unreadable image is `recognized: false`
  /// rather than an error — one bad photo out of five must not discard the
  /// other four.
  func scanBatch(_ images: [ScreenshotUploadImage]) async throws -> ReceiptBatchScanResponse {
    guard !images.isEmpty else { throw Error.api("Select at least one receipt photo.") }
    guard images.count <= Self.maxBatchImages else {
      throw Error.api("Scan at most \(Self.maxBatchImages) receipts at a time.")
    }

    var request = URLRequest(url: client.baseURL.appendingPathComponent("v1/receipts/scan"))
    request.httpMethod = HTTPMethod.post.rawValue
    await attachAuthorization(to: &request)

    var body = MultipartFormBody()
    for (index, image) in images.enumerated() {
      body.addFile(
        name: "file",
        filename: image.filename ?? "receipt-\(index + 1).jpg",
        contentType: image.contentType,
        data: image.data
      )
    }
    request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
    request.httpBody = body.finalizedData()

    let data = try await client.sendRequest(request, errorType: Error.self)
    return try decodeEnveloped(ReceiptBatchScanResponse.self, from: data)
  }

  /// Writes the expenses the user confirmed on the review screen.
  ///
  /// Sends JSON, not images: extraction already happened, so this spends no AI
  /// call and is safe to retry. The backend dedupes on `externalId`, so a
  /// re-submitted batch does not double-insert.
  func commitReceipts(_ payload: ReceiptImportCommitRequest) async throws -> ReceiptImportCommitResponse {
    var request = URLRequest(
      url: client.baseURL.appendingPathComponent("v1/expenses/import/receipts/commit")
    )
    request.httpMethod = HTTPMethod.post.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    await attachAuthorization(to: &request)
    request.httpBody = try JSONEncoder().encode(payload)

    let data = try await client.sendRequest(request, errorType: Error.self)
    return try decodeEnveloped(ReceiptImportCommitResponse.self, from: data)
  }

  private func attachAuthorization(to request: inout URLRequest) async {
    guard let token = await client.authTokenProvider(),
          !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return }
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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

  private func makeUploadRequest(imageData: Data, contentType: String, filename: String) async throws -> URLRequest {
    let base = client.baseURL.appendingPathComponent("v1/receipts/ocr")
    var request = URLRequest(url: base)
    request.httpMethod = HTTPMethod.post.rawValue

    if let token = await client.authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    var body = MultipartFormBody()
    // Backend readImageUpload accepts field "file" or "image".
    body.addFile(
      name: "file",
      filename: filename,
      contentType: contentType.isEmpty ? "image/jpeg" : contentType,
      data: imageData
    )
    request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
    request.httpBody = body.finalizedData()
    return request
  }
}
