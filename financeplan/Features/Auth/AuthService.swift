import Foundation
import StockPlanShared

protocol AuthServicing {
  func login(email: String, password: String) async throws -> AuthResponse
  func signup(
    username: String,
    email: String,
    password: String,
    firstName: String,
    lastName: String,
    dateOfBirth: Date
  ) async throws -> AuthResponse
  func forgotPassword(email: String) async throws -> AuthForgotPasswordResponse
}

protocol AuthSessionStoring: AnyObject {
  var authToken: String { get set }
  var refreshToken: String { get set }
  var loginIsSignup: Bool { get set }
}

final class AuthService: AuthServicing {
  private let environmentManager: AppEnvironmentManager
  private let session: AuthURLSessionProtocol

  init(
    environmentManager: AppEnvironmentManager,
    session: AuthURLSessionProtocol = URLSession.shared
  ) {
    self.environmentManager = environmentManager
    self.session = session
  }

  func login(email: String, password: String) async throws -> AuthResponse {
    try await client().login(AuthLoginRequest(email: email, password: password))
  }

  func signup(
    username: String,
    email: String,
    password: String,
    firstName: String,
    lastName: String,
    dateOfBirth: Date
  ) async throws -> AuthResponse {
    try await client().register(
      AuthRegisterRequest(
        username: username,
        password: password,
        email: email,
        firstName: firstName,
        lastName: lastName,
        dateOfBirth: dateOfBirth
      )
    )
  }

  func forgotPassword(email: String) async throws -> AuthForgotPasswordResponse {
    try await client().forgotPassword(AuthForgotPasswordRequest(email: email))
  }

  private func client() -> AuthHTTPClient {
    AuthHTTPClient(baseURL: environmentManager.current.apiBaseUrl, session: session)
  }
}

final class UserDefaultsAuthSessionStore: AuthSessionStoring {
  private enum Keys {
    static let authToken = "auth_token"
    static let refreshToken = "refresh_token"
    static let loginIsSignup = "login_isSignup"
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var authToken: String {
    get { defaults.string(forKey: Keys.authToken) ?? "" }
    set { defaults.set(newValue, forKey: Keys.authToken) }
  }

  var refreshToken: String {
    get { defaults.string(forKey: Keys.refreshToken) ?? "" }
    set { defaults.set(newValue, forKey: Keys.refreshToken) }
  }

  var loginIsSignup: Bool {
    get {
      if defaults.object(forKey: Keys.loginIsSignup) == nil {
        return true
      }
      return defaults.bool(forKey: Keys.loginIsSignup)
    }
    set { defaults.set(newValue, forKey: Keys.loginIsSignup) }
  }
}
