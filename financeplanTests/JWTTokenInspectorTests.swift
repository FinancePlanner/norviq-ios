import Foundation
import XCTest
@testable import financeplan

final class JWTTokenInspectorTests: XCTestCase {
  func testPayload_DecodesUserIDAndExpiration() throws {
    let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let expiry = Date(timeIntervalSince1970: 1_900_000_000)
    let token = makeJWT(userID: userID, expiresAt: expiry)

    let payload = try XCTUnwrap(JWTTokenInspector.payload(from: token))

    XCTAssertEqual(payload.userID, userID)
    XCTAssertEqual(payload.expiresAt, expiry)
  }

  func testPayload_WithMalformedToken_ReturnsNil() {
    XCTAssertNil(JWTTokenInspector.payload(from: "not-a-jwt"))
  }

  private func makeJWT(userID: UUID, expiresAt: Date) -> String {
    let header = ["alg": "none", "typ": "JWT"]
    let payload: [String: Any] = [
      "userId": userID.uuidString,
      "exp": Int(expiresAt.timeIntervalSince1970)
    ]

    return [
      encodeSegment(header),
      encodeSegment(payload),
      "signature"
    ].joined(separator: ".")
  }

  private func encodeSegment(_ jsonObject: Any) -> String {
    let data = try! JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys])
    return data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
