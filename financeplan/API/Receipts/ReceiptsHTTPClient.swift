import AnyAPI
import Foundation
import OSLog
import StockPlanShared

/// Uploads receipt photos to the backend OCR endpoint. Mirrors the multipart
/// upload approach in `BrokerHTTPClient` (the `Endpoint`/`Parameters` abstraction
/// in `BaseHTTPClient` is for JSON bodies, not binary), while reusing its auth
/// token provider and JSON decoder.
final class ReceiptsHTTPClient: Sendable {

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

  private func makeUploadRequest(imageData: Data, contentType: String, filename: String) async throws -> URLRequest {
    let base = client.baseURL.appendingPathComponent("v1/receipts/ocr")
    var request = URLRequest(url: base)
    request.httpMethod = HTTPMethod.post.rawValue

    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    if let token = await client.authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    request.httpBody = makeUploadBody(
      boundary: boundary,
      imageData: imageData,
      contentType: contentType.isEmpty ? "image/jpeg" : contentType,
      filename: filename
    )
    return request
  }

  private func makeUploadBody(boundary: String, imageData: Data, contentType: String, filename: String) -> Data {
    let newline = "\r\n"
    var body = Data()

    func append(_ text: String) {
      body.append(Data(text.utf8))
    }

    // Backend readImageUpload accepts field "file" or "image".
    append("--\(boundary)\(newline)")
    append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\(newline)")
    append("Content-Type: \(contentType)\(newline)\(newline)")
    body.append(imageData)
    append(newline)
    append("--\(boundary)--\(newline)")

    return body
  }
}
