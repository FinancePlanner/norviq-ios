import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

final class AuthSessionStoreTests: XCTestCase {
  private final class InMemorySecureStore: SecureStringStoring {
    private var values: [String: String] = [:]

    func string(for key: String) -> String? {
      values[key]
    }

    func setString(_ value: String, for key: String) {
      values[key] = value
    }

    func removeValue(for key: String) {
      values.removeValue(forKey: key)
    }
  }

  private final class BrokenSecureStore: SecureStringStoring {
    func string(for key: String) -> String? { nil }
    func setString(_ value: String, for key: String) {}
    func removeValue(for key: String) {}
  }

  func testStoreAuthResponse_PrefersJWTExpirationWhenPresent() throws {
    let defaults = UserDefaults(suiteName: #function)!
    defaults.removePersistentDomain(forName: #function)
    let secureStore = InMemorySecureStore()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let jwtExpiry = now.addingTimeInterval(600)
    let store = UserDefaultsAuthSessionStore(
      defaults: defaults,
      secureStore: secureStore,
      nowProvider: { now }
    )

    store.store(
      authResponse: AuthResponse(
        token: makeJWT(userID: userID, expiresAt: jwtExpiry),
        userId: userID,
        expiresIn: 3600,
        refreshToken: "refresh-123",
        refreshExpiresIn: 86_400,
        username: "valid_user",
        email: "user@example.com",
        firstName: "Jane",
        lastName: "Doe",
        dateOfBirth: Date(timeIntervalSince1970: 946684800)
      )
    )

    XCTAssertEqual(store.authTokenExpiresAt, jwtExpiry)
    XCTAssertEqual(store.refreshTokenExpiresAt, now.addingTimeInterval(86_400))
    XCTAssertEqual(store.currentUserID, userID.uuidString)
    XCTAssertEqual(store.authToken, makeJWT(userID: userID, expiresAt: jwtExpiry))
  }

  func testStoreAuthResponse_WithOpaqueToken_FallsBackToExpiresIn() {
    let defaults = UserDefaults(suiteName: #function)!
    defaults.removePersistentDomain(forName: #function)
    let secureStore = InMemorySecureStore()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let store = UserDefaultsAuthSessionStore(
      defaults: defaults,
      secureStore: secureStore,
      nowProvider: { now }
    )

    store.store(
      authResponse: AuthResponse(
        token: "opaque-token",
        userId: userID,
        expiresIn: 3600,
        refreshToken: "refresh-123",
        refreshExpiresIn: 86_400,
        username: "valid_user",
        email: "user@example.com",
        firstName: "Jane",
        lastName: "Doe",
        dateOfBirth: Date(timeIntervalSince1970: 946684800)
      )
    )

    XCTAssertEqual(store.authTokenExpiresAt, now.addingTimeInterval(3600))
    XCTAssertEqual(store.refreshTokenExpiresAt, now.addingTimeInterval(86_400))
  }

  func testStoreAuthResponse_WhenSecureStoreCannotReadBack_FallsBackToUserDefaults() {
    let defaults = UserDefaults(suiteName: #function)!
    defaults.removePersistentDomain(forName: #function)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let store = UserDefaultsAuthSessionStore(
      defaults: defaults,
      secureStore: BrokenSecureStore(),
      nowProvider: { now }
    )

    store.store(
      authResponse: AuthResponse(
        token: "opaque-token",
        userId: userID,
        expiresIn: 3600,
        refreshToken: "refresh-123",
        refreshExpiresIn: 86_400,
        username: "valid_user",
        email: "user@example.com",
        firstName: "Jane",
        lastName: "Doe",
        dateOfBirth: Date(timeIntervalSince1970: 946684800)
      )
    )

    XCTAssertEqual(store.authToken, "opaque-token")
    XCTAssertEqual(store.refreshToken, "refresh-123")
    XCTAssertEqual(defaults.string(forKey: "auth_token"), "opaque-token")
    XCTAssertEqual(defaults.string(forKey: "refresh_token"), "refresh-123")
  }

  private func makeJWT(userID: UUID, expiresAt: Date) -> String {
    let header = ["alg": "none", "typ": "JWT"]
    let payload: [String: Any] = [
      "userId": userID.uuidString,
      "exp": Int(expiresAt.timeIntervalSince1970),
    ]

    return [
      encodeSegment(header),
      encodeSegment(payload),
      "signature",
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
