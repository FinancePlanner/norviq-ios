import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class LoginViewModelTests: XCTestCase {
  private final class AuthServiceMock: AuthServicing {
    var loginCalls = 0
    var signupCalls = 0
    var forgotPasswordCalls = 0
    var refreshCalls = 0
    var oauthSignInCalls = 0
    var verifyMFACalls = 0
    var resendMFACalls = 0

    var lastLoginEmail: String?
    var lastSignupUsername: String?
    var lastSignupEmail: String?
    var lastSignupConfirmPassword: String?
    var lastSignupDateOfBirth: Date?
    var lastForgotPasswordEmail: String?
    var lastRefreshToken: String?
    var lastMFAChallengeId: UUID?
    var lastMFACode: String?
    var lastOAuthProvider: OAuthProviderKind?
    var logoutCalls = 0
    var lastLogoutRefreshToken: String?
    var loginDelayNanoseconds: UInt64 = 0

    var loginResult: Result<AuthLoginOutcomePayload, Error> = .failure(MockError.notConfigured)
    var signupResult: Result<Void, Error> = .failure(MockError.notConfigured)
    var forgotPasswordResult: Result<AuthForgotPasswordResponse, Error> = .failure(MockError.notConfigured)
    var refreshResult: Result<AuthResponse, Error> = .failure(MockError.notConfigured)
    var oauthSignInResult: Result<AuthLoginOutcomePayload, Error> = .failure(MockError.notConfigured)
    var verifyMFAResult: Result<AuthResponse, Error> = .failure(MockError.notConfigured)
    var resendMFAResult: Result<AuthMFAChallengeResponsePayload, Error> = .failure(MockError.notConfigured)

    func login(email: String, password _: String) async throws -> AuthLoginOutcomePayload {
      loginCalls += 1
      lastLoginEmail = email
      if loginDelayNanoseconds > 0 {
        try await Task.sleep(nanoseconds: loginDelayNanoseconds)
      }
      return try loginResult.get()
    }

    func signup(
      username: String,
      email: String,
      password: String,
      confirmPassword: String,
      dateOfBirth: Date
    ) async throws {
      signupCalls += 1
      lastSignupUsername = username
      lastSignupEmail = email
      lastSignupConfirmPassword = confirmPassword
      XCTAssertEqual(password, confirmPassword)
      lastSignupDateOfBirth = dateOfBirth
      _ = try signupResult.get()
    }

    func forgotPassword(email: String) async throws -> AuthForgotPasswordResponse {
      forgotPasswordCalls += 1
      lastForgotPasswordEmail = email
      return try forgotPasswordResult.get()
    }

    func verifyMFA(challengeId: UUID, code: String) async throws -> AuthResponse {
      verifyMFACalls += 1
      lastMFAChallengeId = challengeId
      lastMFACode = code
      return try verifyMFAResult.get()
    }

    func resendMFA(challengeId: UUID) async throws -> AuthMFAChallengeResponsePayload {
      resendMFACalls += 1
      lastMFAChallengeId = challengeId
      return try resendMFAResult.get()
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
    func oauthSignIn(provider: OAuthProviderKind) async throws -> AuthLoginOutcomePayload {
      oauthSignInCalls += 1
      lastOAuthProvider = provider
      return try oauthSignInResult.get()
    }
  }

  private final class AuthSessionStoreMock: AuthSessionStoring {
    var authToken = ""
    var refreshToken = ""
    var authTokenExpiresAt: Date?
    var refreshTokenExpiresAt: Date?
    var loginIsSignup = true
    var currentUserID = ""
    var currentUsername = ""
    private var importedUserIDs: Set<String> = []

    func store(authResponse: AuthResponse) {
      authToken = authResponse.token
      refreshToken = authResponse.refreshToken
      currentUserID = authResponse.userId.uuidString
      currentUsername = authResponse.username
      authTokenExpiresAt = Date().addingTimeInterval(TimeInterval(authResponse.expiresIn))
      refreshTokenExpiresAt = Date().addingTimeInterval(TimeInterval(authResponse.refreshExpiresIn))
    }

    func clearSession() {
      authToken = ""
      refreshToken = ""
      authTokenExpiresAt = nil
      refreshTokenExpiresAt = nil
      currentUserID = ""
      currentUsername = ""
    }

    func hasCompletedInitialStockImport(for userID: String) -> Bool {
      importedUserIDs.contains(userID)
    }

    func markInitialStockImportCompleted(for userID: String) {
      importedUserIDs.insert(userID)
    }
  }

  private enum MockError: Error {
    case notConfigured
    case failed
  }

  func testInit_UsesPersistedSignupMode() async {
    let service = AuthServiceMock()
    let store = AuthSessionStoreMock()
    store.loginIsSignup = false

    let viewModel = LoginViewModel(authService: service, sessionStore: store)
    await Task.yield()

    XCTAssertFalse(viewModel.isSignup)
    XCTAssertEqual(viewModel.signupFieldsOpacity, 0)
  }

  func testToggleMode_PersistsToStore() async {
    let service = AuthServiceMock()
    let store = AuthSessionStoreMock()
    let viewModel = LoginViewModel(authService: service, sessionStore: store)
    await Task.yield()

    viewModel.hideSignup()
    XCTAssertFalse(viewModel.isSignup)
    XCTAssertFalse(store.loginIsSignup)

    viewModel.showSignup()
    XCTAssertTrue(viewModel.isSignup)
    XCTAssertTrue(store.loginIsSignup)
  }

  func testSubmitLogin_WithInvalidEmail_SetsValidationErrorAndSkipsRequest() async {
    let service = AuthServiceMock()
    let store = AuthSessionStoreMock()
    store.loginIsSignup = false
    let viewModel = LoginViewModel(authService: service, sessionStore: store)
    viewModel.username = "not-an-email"
    viewModel.password = "Password123!"

    await viewModel.submit()

    XCTAssertEqual(service.loginCalls, 0)
    XCTAssertEqual(viewModel.fieldErrors[.username], "Please enter a valid email address")
  }

  func testSubmitLogin_WithValidCredentials_PersistsTokens() async throws {
    let service = AuthServiceMock()
    let store = AuthSessionStoreMock()
    store.loginIsSignup = false
    let viewModel = LoginViewModel(authService: service, sessionStore: store)
    let expected = AuthResponse(
      token: "token-abc",
      userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
      expiresIn: 3600,
      refreshToken: "refresh-abc",
      refreshExpiresIn: 86_400,
      username: "valid_user",
      email: "user@example.com",
      dateOfBirth: Date(timeIntervalSince1970: 946684800)
    )
    service.loginResult = .success(.authenticated(expected))

    viewModel.username = "user@example.com"
    viewModel.password = "Password123!"

    await viewModel.submit()

    XCTAssertEqual(service.loginCalls, 1)
    XCTAssertEqual(service.lastLoginEmail, "user@example.com")
    XCTAssertEqual(store.authToken, expected.token)
    XCTAssertEqual(store.refreshToken, expected.refreshToken)
    XCTAssertEqual(store.currentUserID, expected.userId.uuidString)
    XCTAssertEqual(store.currentUsername, expected.username)
    XCTAssertNil(viewModel.error)
  }

  func testSubmitLogin_WhenAlreadySubmitting_IgnoresSecondRequest() async {
    let service = AuthServiceMock()
    let store = AuthSessionStoreMock()
    store.loginIsSignup = false
    let viewModel = LoginViewModel(authService: service, sessionStore: store)
    service.loginDelayNanoseconds = 300_000_000
    service.loginResult = .success(.authenticated(
      AuthResponse(
        token: "token",
        userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        expiresIn: 3600,
        refreshToken: "refresh",
        refreshExpiresIn: 86_400,
        username: "valid_user",
        email: "user@example.com",
        dateOfBirth: Date(timeIntervalSince1970: 946684800)
      )
    ))

    viewModel.username = "user@example.com"
    viewModel.password = "Password123!"

    async let first: Void = viewModel.submit()
    await Task.yield()
    async let second: Void = viewModel.submit()
    _ = await (first, second)

    XCTAssertEqual(service.loginCalls, 1)
  }

  func testSubmitSignup_WithInvalidEmail_SetsValidationErrorAndSkipsRequest() async {
    let service = AuthServiceMock()
    let store = AuthSessionStoreMock()
    let viewModel = LoginViewModel(authService: service, sessionStore: store)
    viewModel.isSignup = true
    viewModel.username = "valid_user"
    viewModel.email = "invalid-email"
    viewModel.password = "Password123!"

    await viewModel.submit()

    XCTAssertEqual(service.signupCalls, 0)
    XCTAssertEqual(viewModel.fieldErrors[.email], "Please enter a valid email address")
  }

  func testSubmitSignup_WhenServiceSucceeds_ShowsLoginAndDoesNotPersistTokens() async {
    let service = AuthServiceMock()
    let store = AuthSessionStoreMock()
    let viewModel = LoginViewModel(authService: service, sessionStore: store)
    service.signupResult = .success(())

    viewModel.isSignup = true
    viewModel.username = "valid_user"
    viewModel.email = "user@example.com"
    viewModel.password = "Password123!"
    viewModel.confirmPassword = "Password123!"
    viewModel.dateOfBirth = Date(timeIntervalSince1970: 946684800)

    await viewModel.submit()

    XCTAssertEqual(service.signupCalls, 1)
    XCTAssertFalse(viewModel.isSignup)
    XCTAssertEqual(viewModel.username, "user@example.com")
    XCTAssertEqual(viewModel.password, "")
    XCTAssertEqual(viewModel.infoMessage, "Account created. Please sign in.")
    XCTAssertEqual(store.authToken, "")
    XCTAssertEqual(store.refreshToken, "")
  }

  func testRequestForgotPassword_ForwardsToServiceAndReturnsMessage() async throws {
    let service = AuthServiceMock()
    let store = AuthSessionStoreMock()
    let viewModel = LoginViewModel(authService: service, sessionStore: store)
    service.forgotPasswordResult = .success(
      AuthForgotPasswordResponse(
        message: "Reset instructions sent.",
        resetCode: nil
      )
    )

    let message = try await viewModel.requestForgotPassword(for: "user@example.com")

    XCTAssertEqual(message, "Reset instructions sent.")
    XCTAssertEqual(service.forgotPasswordCalls, 1)
    XCTAssertEqual(service.lastForgotPasswordEmail, "user@example.com")
  }

  func testSubmitSignup_WhenServiceFails_SetsErrorMessage() async {
    let service = AuthServiceMock()
    let store = AuthSessionStoreMock()
    let viewModel = LoginViewModel(authService: service, sessionStore: store)
    service.signupResult = .failure(MockError.failed)

    let expectedDOB = Date(timeIntervalSince1970: 946684800)

    viewModel.isSignup = true
    viewModel.username = "valid_user"
    viewModel.email = "user@example.com"
    viewModel.dateOfBirth = expectedDOB
    viewModel.password = "Password123!"
    viewModel.confirmPassword = "Password123!"

    await viewModel.submit()

    XCTAssertEqual(service.signupCalls, 1)
    XCTAssertEqual(service.lastSignupUsername, "valid_user")
    XCTAssertEqual(service.lastSignupEmail, "user@example.com")
    XCTAssertEqual(service.lastSignupConfirmPassword, "Password123!")
    XCTAssertEqual(service.lastSignupDateOfBirth, expectedDOB)
    XCTAssertEqual(viewModel.error, "Could not sign up. Please try again.")
  }

  func testSubmitLogin_WhenMFARequired_PresentsMFAFlow() async {
    let service = AuthServiceMock()
    let store = AuthSessionStoreMock()
    store.loginIsSignup = false
    let viewModel = LoginViewModel(authService: service, sessionStore: store)

    let challenge = AuthMFAChallengeResponsePayload(
      challengeId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
      channel: .email,
      maskedDestination: "us***@e***.com",
      expiresIn: 300,
      resendAvailableIn: 5
    )
    service.loginResult = .success(.mfaRequired(challenge))

    viewModel.username = "user@example.com"
    viewModel.password = "Password123!"

    await viewModel.submit()

    XCTAssertEqual(service.loginCalls, 1)
    XCTAssertNotNil(viewModel.pendingMFAChallenge)
    XCTAssertEqual(viewModel.pendingMFAChallenge?.challengeId, challenge.challengeId)
    XCTAssertEqual(store.authToken, "")
  }

  func testSubmitMFA_WhenVerifySucceeds_PersistsSessionAndDismissesMFA() async {
    let service = AuthServiceMock()
    let store = AuthSessionStoreMock()
    let viewModel = LoginViewModel(authService: service, sessionStore: store)
    let challengeID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let expectedAuth = AuthResponse(
      token: "token-mfa",
      userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
      expiresIn: 3600,
      refreshToken: "refresh-mfa",
      refreshExpiresIn: 86_400,
      username: "valid_user",
      email: "user@example.com",
      dateOfBirth: Date(timeIntervalSince1970: 946684800)
    )
    service.verifyMFAResult = .success(expectedAuth)

    viewModel.pendingMFAChallenge = AuthMFAChallengeResponsePayload(
      challengeId: challengeID,
      channel: .email,
      maskedDestination: "us***@e***.com",
      expiresIn: 300,
      resendAvailableIn: 0
    )
    viewModel.mfaCode = "123456"

    await viewModel.submitMFA()

    XCTAssertEqual(service.verifyMFACalls, 1)
    XCTAssertEqual(service.lastMFAChallengeId, challengeID)
    XCTAssertEqual(service.lastMFACode, "123456")
    XCTAssertEqual(store.authToken, "token-mfa")
    XCTAssertNil(viewModel.pendingMFAChallenge)
  }
}
