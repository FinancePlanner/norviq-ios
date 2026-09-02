import AnyAPI
import Foundation
import OSLog
import StockPlanShared

/// Drives the spreadsheet import endpoints.
///
/// The upload is multipart and hand-built, following `ReceiptsHTTPClient` — the
/// `Endpoint`/`Parameters` abstraction in `BaseHTTPClient` is for JSON bodies,
/// not binary. Everything after the upload is ordinary JSON.
nonisolated final class SpreadsheetImportHTTPClient: Sendable {

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
        // 404 here almost always means the hour-long session lapsed while the
        // user was still reviewing, so say the useful thing rather than "404".
        if code == 404 {
          return "That import expired. Upload the file again."
        }
        if code == 409 {
          return "This import was already applied."
        }
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

  let client: BaseHTTPClient

  init(
    baseURL: URL,
    session: any HTTPClientSession = URLSession.shared,
    authTokenProvider: @escaping @Sendable () async -> String? = { nil }
  ) {
    self.client = BaseHTTPClient(
      baseURL: baseURL,
      session: session,
      authTokenProvider: authTokenProvider,
      logger: Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
        category: "SpreadsheetImportHTTPClient"
      ),
      decoder: .stockPlanShared
    )
  }

  // MARK: - Requests

  /// Uploads a workbook and returns the proposed mapping plus a preview.
  /// Pro-gated, and may spend an AI call, so callers should not retry blindly.
  func analyze(
    fileData: Data,
    filename: String
  ) async throws -> SpreadsheetImportAnalysisResponse {
    let request = try await makeUploadRequest(fileData: fileData, filename: filename)
    let data = try await client.sendRequest(request, errorType: Error.self)
    return try decode(SpreadsheetImportAnalysisResponse.self, from: data)
  }

  /// Re-fetches a session, for resuming a review.
  func fetch(sessionId: String) async throws -> SpreadsheetImportAnalysisResponse {
    let request = try await makeJSONRequest(
      path: "v1/expenses/import/spreadsheet/\(sessionId)", method: .get, body: Optional<Int>.none
    )
    let data = try await client.sendRequest(request, errorType: Error.self)
    return try decode(SpreadsheetImportAnalysisResponse.self, from: data)
  }

  /// Applies the user's decisions and returns what would be imported. Cheap and
  /// repeatable: no AI call, nothing written.
  func preview(
    sessionId: String,
    decision: SpreadsheetImportDecisionRequest
  ) async throws -> SpreadsheetImportPreviewResponse {
    let request = try await makeJSONRequest(
      path: "v1/expenses/import/spreadsheet/\(sessionId)/preview", method: .post, body: decision
    )
    let data = try await client.sendRequest(request, errorType: Error.self)
    return try decode(SpreadsheetImportPreviewResponse.self, from: data)
  }

  /// Writes the approved rows.
  ///
  /// Sends an `Idempotency-Key` so a retry after a dropped connection cannot
  /// insert the same expenses twice.
  func commit(
    sessionId: String,
    decision: SpreadsheetImportDecisionRequest,
    idempotencyKey: String = UUID().uuidString
  ) async throws -> SpreadsheetImportCommitResponse {
    var request = try await makeJSONRequest(
      path: "v1/expenses/import/spreadsheet/\(sessionId)/commit", method: .post, body: decision
    )
    request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
    let data = try await client.sendRequest(request, errorType: Error.self)
    return try decode(SpreadsheetImportCommitResponse.self, from: data)
  }

  /// Releases the session early. Best-effort: the server expires it within the
  /// hour regardless, so a failure here is not worth surfacing to the user.
  func discard(sessionId: String) async {
    do {
      let request = try await makeJSONRequest(
        path: "v1/expenses/import/spreadsheet/\(sessionId)", method: .delete, body: Optional<Int>.none
      )
      _ = try await client.sendRequest(request, errorType: Error.self)
    } catch {
      client.logger.debug("discarding import session failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  // MARK: - Request building

  private func makeJSONRequest(
    path: String,
    method: HTTPMethod,
    body: (some Encodable)?
  ) async throws -> URLRequest {
    var request = URLRequest(url: client.baseURL.appendingPathComponent(path))
    request.httpMethod = method.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let body {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONEncoder().encode(body)
    }
    await attachAuthorization(to: &request)
    return request
  }

  private func makeUploadRequest(fileData: Data, filename: String) async throws -> URLRequest {
    var request = URLRequest(url: client.baseURL.appendingPathComponent("v1/expenses/import/spreadsheet"))
    request.httpMethod = HTTPMethod.post.rawValue

    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    await attachAuthorization(to: &request)

    request.httpBody = makeUploadBody(boundary: boundary, fileData: fileData, filename: filename)
    return request
  }

  private func makeUploadBody(boundary: String, fileData: Data, filename: String) -> Data {
    let newline = "\r\n"
    var body = Data()

    func append(_ text: String) {
      body.append(Data(text.utf8))
    }

    // Backend readUpload accepts field "file" or "spreadsheet".
    append("--\(boundary)\(newline)")
    append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\(newline)")
    append(
      "Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\(newline)\(newline)"
    )
    body.append(fileData)
    append(newline)
    append("--\(boundary)--\(newline)")

    return body
  }

  private func attachAuthorization(to request: inout URLRequest) async {
    guard let token = await client.authTokenProvider(),
          !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return }
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
  }

  /// Unwraps the API envelope when present, matching the other clients.
  private func decode<T: Codable & Sendable>(_ type: T.Type, from data: Data) throws -> T {
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
}
