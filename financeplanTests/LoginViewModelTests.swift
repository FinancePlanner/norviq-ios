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

    var lastLoginEmail: String?
    var lastSignupUsername: String?
    var lastSignupEmail: String?
    var lastSignupFirstName: String?
    var lastSignupLastName: String?
    var lastSignupDateOfBirth: Date?
    var lastForgotPasswordEmail: String?
    var logoutCalls = 0
    var lastLogoutRefreshToken: String?
    var loginDelayNanoseconds: UInt64 = 0

    var loginResult: Result<AuthResponse, Error> = .failure(MockError.notConfigured)
    var signupResult: Result<Void, Error> = .failure(MockError.notConfigured)
    var forgotPasswordResult: Result<AuthForgotPasswordResponse, Error> = .failure(MockError.notConfigured)

    func login(email: String, password _: String) async throws -> AuthResponse {
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
      password _: String,
      firstName: String,
      lastName: String,
      dateOfBirth: Date
    ) async throws {
      signupCalls += 1
      lastSignupUsername = username
      lastSignupEmail = email
      lastSignupFirstName = firstName
      lastSignupLastName = lastName
      lastSignupDateOfBirth = dateOfBirth
      _ = try signupResult.get()
    }

    func forgotPassword(email: String) async throws -> AuthForgotPasswordResponse {
      forgotPasswordCalls += 1
      lastForgotPasswordEmail = email
      return try forgotPasswordResult.get()
    }

    func logout(refreshToken: String) async {
      logoutCalls += 1
      lastLogoutRefreshToken = refreshToken
    }
  }

  private final class AuthSessionStoreMock: AuthSessionStoring {
    var authToken = ""
    var refreshToken = ""
    var loginIsSignup = true
    var currentUserID = ""
    var currentUsername = ""
    private var importedUserIDs: Set<String> = []

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
    viewModel.password = "Password123"

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
      firstName: "Jane",
      lastName: "Doe",
      dateOfBirth: Date(timeIntervalSince1970: 946684800)
    )
    service.loginResult = .success(expected)

    viewModel.username = "user@example.com"
    viewModel.password = "Password123"

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
    service.loginResult = .success(
      AuthResponse(
        token: "token",
        userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        expiresIn: 3600,
        refreshToken: "refresh",
        refreshExpiresIn: 86_400,
        username: "valid_user",
        email: "user@example.com",
        firstName: "Jane",
        lastName: "Doe",
        dateOfBirth: Date(timeIntervalSince1970: 946684800)
      )
    )

    viewModel.username = "user@example.com"
    viewModel.password = "Password123"

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
    viewModel.firstName = "Jane"
    viewModel.lastName = "Doe"
    viewModel.password = "Password123"

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
    viewModel.firstName = "Jane"
    viewModel.lastName = "Doe"
    viewModel.password = "Password123"
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
    viewModel.firstName = "Jane"
    viewModel.lastName = "Doe"
    viewModel.dateOfBirth = expectedDOB
    viewModel.password = "Password123"

    await viewModel.submit()

    XCTAssertEqual(service.signupCalls, 1)
    XCTAssertEqual(service.lastSignupUsername, "valid_user")
    XCTAssertEqual(service.lastSignupEmail, "user@example.com")
    XCTAssertEqual(service.lastSignupFirstName, "Jane")
    XCTAssertEqual(service.lastSignupLastName, "Doe")
    XCTAssertEqual(service.lastSignupDateOfBirth, expectedDOB)
    XCTAssertEqual(viewModel.error, "Could not sign up. Please try again.")
  }
}
