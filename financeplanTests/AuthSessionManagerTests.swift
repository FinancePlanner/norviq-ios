import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class AuthSessionManagerTests: XCTestCase {
  private final class AuthServiceMock: AuthServicing, @unchecked Sendable {
    var refreshCalls = 0
    var logoutCalls = 0
    var lastRefreshToken: String?
    var lastLogoutRefreshToken: String?
    var refreshResult: Result<AuthResponse, Error> = .failure(MockError.notConfigured)

    func login(email: String, password: String) async throws -> AuthLoginOutcomePayload {
      throw MockError.notConfigured
    }

    func signup(
      username: String,
      email: String,
      password: String,
      confirmPassword: String,
      dateOfBirth: Date
    ) async throws {
      throw MockError.notConfigured
    }

    func forgotPassword(email: String) async throws -> AuthForgotPasswordResponse {
      throw MockError.notConfigured
    }

    func verifyMFA(challengeId _: UUID, code _: String) async throws -> AuthResponse {
      throw MockError.notConfigured
    }

    func resendMFA(challengeId _: UUID) async throws -> AuthMFAChallengeResponsePayload {
      throw MockError.notConfigured
    }

    func refresh(refreshToken: String) async throws -> AuthResponse {
      refreshCalls += 1
      lastRefreshToken = refreshToken
      return try refreshResult.get()
    }

    func logout(refreshToken: String) async {
      logoutCalls += 1
      lastLogoutRefreshToken = refreshToken
    }

    @MainActor
    func oauthSignIn(provider _: OAuthProviderKind) async throws -> AuthLoginOutcomePayload {
      throw MockError.notConfigured
    }
  }

  private final class SessionStoreMock: AuthSessionStoring, @unchecked Sendable {
    var authToken = ""
    var refreshToken = ""
    var authTokenExpiresAt: Date?
    var refreshTokenExpiresAt: Date?
    var loginIsSignup = true
    var currentUserID = ""
    var currentUsername = ""

    func setAuthToken(_ value: String) async { authToken = value }
    func setRefreshToken(_ value: String) async { refreshToken = value }
    func setAuthTokenExpiresAt(_ value: Date?) async { authTokenExpiresAt = value }
    func setRefreshTokenExpiresAt(_ value: Date?) async { refreshTokenExpiresAt = value }
    func setLoginIsSignup(_ value: Bool) async { loginIsSignup = value }
    func setCurrentUserID(_ value: String) async { currentUserID = value }
    func setCurrentUsername(_ value: String) async { currentUsername = value }

    func store(authResponse: AuthResponse) async {
      authToken = authResponse.token
      refreshToken = authResponse.refreshToken
      currentUserID = authResponse.userId.uuidString
      currentUsername = authResponse.username
      authTokenExpiresAt = JWTTokenInspector.expirationDate(in: authResponse.token)
      refreshTokenExpiresAt = Date().addingTimeInterval(TimeInterval(authResponse.refreshExpiresIn))
    }

    func clearSession() async {
      authToken = ""
      refreshToken = ""
      authTokenExpiresAt = nil
      refreshTokenExpiresAt = nil
      currentUserID = ""
      currentUsername = ""
    }

    func hasCompletedInitialStockImport(for userID: String) -> Bool { false }
    func markInitialStockImportCompleted(for userID: String) {}
  }

  private enum MockError: Error {
    case notConfigured
  }

  func testValidAccessToken_UsesUnexpiredJWTWithoutRefreshing() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let service = AuthServiceMock()
    let store = SessionStoreMock()
    store.authToken = makeJWT(userID: userID, expiresAt: now.addingTimeInterval(600))

    let manager = AuthSessionManager(
      authService: service,
      sessionStore: store,
      nowProvider: { now },
      refreshLeeway: 60
    )

    let token = try await manager.validAccessToken()

    XCTAssertEqual(token, store.authToken)
    XCTAssertEqual(store.currentUserID, userID.uuidString)
    XCTAssertEqual(service.refreshCalls, 0)
  }

  func testValidAccessToken_WhenLocalExpiryCannotBeResolved_ReturnsTokenWithoutRefreshing() async throws {
    let service = AuthServiceMock()
    let store = SessionStoreMock()
    store.authToken = "opaque-access-token"
    store.refreshToken = "refresh-123"

    let manager = AuthSessionManager(
      authService: service,
      sessionStore: store,
      nowProvider: { Date(timeIntervalSince1970: 1_800_000_000) },
      refreshLeeway: 10
    )

    let token = try await manager.validAccessToken()

    XCTAssertEqual(token, "opaque-access-token")
    XCTAssertEqual(service.refreshCalls, 0)
  }

  func testValidAccessToken_WhenTokenIsStillValidAndRefreshFails_UsesCurrentToken() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let service = AuthServiceMock()
    let store = SessionStoreMock()
    let currentToken = makeJWT(userID: userID, expiresAt: now.addingTimeInterval(5))
    store.authToken = currentToken
    store.refreshToken = "refresh-123"
    store.refreshTokenExpiresAt = now.addingTimeInterval(3600)
    service.refreshResult = .failure(MockError.notConfigured)

    let manager = AuthSessionManager(
      authService: service,
      sessionStore: store,
      nowProvider: { now },
      refreshLeeway: 10
    )

    let token = try await manager.validAccessToken()

    XCTAssertEqual(token, currentToken)
    XCTAssertEqual(store.authToken, currentToken)
    XCTAssertEqual(service.refreshCalls, 1)
  }

  func testValidAccessToken_WhenExpiredJWTAndRefreshIsValid_RefreshesSession() async throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let refreshedToken = makeJWT(userID: userID, expiresAt: now.addingTimeInterval(3600))
    let service = AuthServiceMock()
    let store = SessionStoreMock()
    store.authToken = makeJWT(userID: userID, expiresAt: now.addingTimeInterval(-10))
    store.refreshToken = "refresh-123"
    store.refreshTokenExpiresAt = now.addingTimeInterval(7200)
    service.refreshResult = .success(
      AuthResponse(
        token: refreshedToken,
        userId: userID,
        expiresIn: 3600,
        refreshToken: "refresh-456",
        refreshExpiresIn: 86_400,
        username: "valid_user",
        email: "user@example.com",
        dateOfBirth: Date(timeIntervalSince1970: 946684800)
      )
    )

    let manager = AuthSessionManager(
      authService: service,
      sessionStore: store,
      nowProvider: { now },
      refreshLeeway: 60
    )

    let token = try await manager.validAccessToken()

    XCTAssertEqual(token, refreshedToken)
    XCTAssertEqual(store.authToken, refreshedToken)
    XCTAssertEqual(store.refreshToken, "refresh-456")
    XCTAssertEqual(service.refreshCalls, 1)
    XCTAssertEqual(service.lastRefreshToken, "refresh-123")
  }

  func testValidAccessToken_WhenSessionExpired_ClearsStoredSession() async {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let service = AuthServiceMock()
    let store = SessionStoreMock()
    store.authToken = makeJWT(userID: userID, expiresAt: now.addingTimeInterval(-10))
    store.refreshToken = "refresh-123"
    store.refreshTokenExpiresAt = now.addingTimeInterval(-5)
    store.currentUserID = userID.uuidString
    store.currentUsername = "valid_user"

    let manager = AuthSessionManager(
      authService: service,
      sessionStore: store,
      nowProvider: { now },
      refreshLeeway: 60
    )

    do {
      _ = try await manager.validAccessToken()
      XCTFail("Expected session expiration")
    } catch let error as AuthSessionError {
      XCTAssertEqual(error, .sessionExpired)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    XCTAssertEqual(store.authToken, "")
    XCTAssertEqual(store.refreshToken, "")
    XCTAssertEqual(store.currentUserID, "")
    XCTAssertEqual(store.currentUsername, "")
  }

  func testLogout_CallsServiceAndClearsSession() async {
    let service = AuthServiceMock()
    let store = SessionStoreMock()
    store.authToken = "access"
    store.refreshToken = "refresh-123"
    store.currentUserID = "user-123"

    let manager = AuthSessionManager(authService: service, sessionStore: store)
    await manager.logout()

    XCTAssertEqual(service.logoutCalls, 1)
    XCTAssertEqual(service.lastLogoutRefreshToken, "refresh-123")
    XCTAssertEqual(store.authToken, "")
    XCTAssertEqual(store.refreshToken, "")
    XCTAssertEqual(store.currentUserID, "")
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
