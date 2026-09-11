import Foundation

/// Builds `multipart/form-data` request bodies.
///
/// `BaseHTTPClient`'s `Endpoint`/`Parameters` abstraction encodes JSON only, so
/// every binary upload has to assemble its own body. Three clients each grew
/// their own near-identical copy of this (receipts, broker CSV, spreadsheet
/// import); this is the one they share instead.
/// `nonisolated` because every caller is a `nonisolated` HTTP client. Under
/// this project's default main-actor isolation the type would otherwise be
/// MainActor-bound and unusable from them.
nonisolated struct MultipartFormBody {
  /// Boundaries must not appear in the payload. A UUID is the usual way to be
  /// sure of that without scanning the bytes.
  let boundary: String

  private var parts = Data()

  init(boundary: String = "Boundary-\(UUID().uuidString)") {
    self.boundary = boundary
  }

  /// The value for the request's `Content-Type` header.
  var contentType: String {
    "multipart/form-data; boundary=\(boundary)"
  }

  /// Appends a plain text field.
  mutating func addField(name: String, value: String) {
    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"\(escaped(name))\"\r\n\r\n")
    append("\(value)\r\n")
  }

  /// Appends a file part. Repeat the same `name` to send several files under
  /// one field, which is how the backend receives a batch of screenshots.
  mutating func addFile(
    name: String,
    filename: String,
    contentType: String,
    data: Data
  ) {
    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"\(escaped(name))\"; filename=\"\(escaped(filename))\"\r\n")
    append("Content-Type: \(contentType.isEmpty ? "application/octet-stream" : contentType)\r\n\r\n")
    parts.append(data)
    append("\r\n")
  }

  /// Finishes the body with the closing boundary. Call once, last.
  func finalizedData() -> Data {
    var body = parts
    body.append(Data("--\(boundary)--\r\n".utf8))
    return body
  }

  private mutating func append(_ text: String) {
    parts.append(Data(text.utf8))
  }

  /// Quotes inside a `Content-Disposition` parameter would end the value early.
  /// Filenames come from the photo library and the user, so they are not
  /// trustworthy input.
  private func escaped(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\r", with: "")
      .replacingOccurrences(of: "\n", with: "")
  }
}
