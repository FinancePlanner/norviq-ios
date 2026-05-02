import Foundation

enum JWTTokenInspector {
  struct Payload: Equatable {
    let userID: UUID?
    let expiresAt: Date?
  }

  nonisolated static func payload(from token: String) -> Payload? {
    let segments = token.split(separator: ".", omittingEmptySubsequences: false)
    guard segments.count >= 2,
          let data = Data(base64URLEncoded: String(segments[1])),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }

    let userId = (json["userId"] as? String).flatMap(UUID.init(uuidString:))
    let exp = json["exp"] as? Double
    let expiresAt = exp.map(Date.init(timeIntervalSince1970:))
    return Payload(userID: userId, expiresAt: expiresAt)
  }

  nonisolated static func expirationDate(in token: String) -> Date? {
    payload(from: token)?.expiresAt
  }

  nonisolated static func userID(in token: String) -> UUID? {
    payload(from: token)?.userID
  }
}

private extension Data {
  nonisolated init?(base64URLEncoded value: String) {
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
