import Foundation

enum JWTTokenInspector {
  struct Payload: Equatable {
    let userID: UUID?
    let expiresAt: Date?
  }

  private struct Claims: Decodable {
    let userId: UUID?
    let exp: Double?
  }

  static func payload(from token: String) -> Payload? {
    let segments = token.split(separator: ".", omittingEmptySubsequences: false)
    guard segments.count >= 2,
          let data = Data(base64URLEncoded: String(segments[1])),
          let claims = try? JSONDecoder().decode(Claims.self, from: data) else {
      return nil
    }

    let expiresAt = claims.exp.map(Date.init(timeIntervalSince1970:))
    return Payload(userID: claims.userId, expiresAt: expiresAt)
  }

  static func expirationDate(in token: String) -> Date? {
    payload(from: token)?.expiresAt
  }

  static func userID(in token: String) -> UUID? {
    payload(from: token)?.userID
  }
}

private extension Data {
  init?(base64URLEncoded value: String) {
    var base64 = value
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")

    let remainder = base64.count % 4
    if remainder != 0 {
      base64.append(String(repeating: "=", count: 4 - remainder))
    }

    self.init(base64Encoded: base64)
  }
}
