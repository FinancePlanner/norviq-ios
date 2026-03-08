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
  ) async throws
  func forgotPassword(email: String) async throws -> AuthForgotPasswordResponse
  func refresh(refreshToken: String) async throws -> AuthResponse
  func logout(refreshToken: String) async
}

protocol AuthSessionStoring: AnyObject {
  var authToken: String { get set }
  var refreshToken: String { get set }
  var authTokenExpiresAt: Date? { get set }
  var refreshTokenExpiresAt: Date? { get set }
  var loginIsSignup: Bool { get set }
  var currentUserID: String { get set }
  var currentUsername: String { get set }

  func store(authResponse: AuthResponse)
  func clearSession()
  func hasCompletedInitialStockImport(for userID: String) -> Bool
  func markInitialStockImportCompleted(for userID: String)
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
  ) async throws {
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

  func refresh(refreshToken: String) async throws -> AuthResponse {
    try await client().refresh(AuthRefreshRequest(refreshToken: refreshToken))
  }

  func logout(refreshToken: String) async {
    guard !refreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return
    }
    try? await client().logout(AuthRefreshRequest(refreshToken: refreshToken))
  }

  private func client() -> AuthHTTPClient {
    AuthHTTPClient(baseURL: environmentManager.current.apiBaseUrl, session: session)
  }
}

final class UserDefaultsAuthSessionStore: AuthSessionStoring, @unchecked Sendable {
  private enum Keys {
    static let authToken = "auth_token"
    static let refreshToken = "refresh_token"
    static let authTokenExpiresAt = "auth_token_expires_at"
    static let refreshTokenExpiresAt = "refresh_token_expires_at"
    static let loginIsSignup = "login_isSignup"
    static let currentUserID = "current_user_id"
    static let currentUsername = "current_username"
    static let initialStockImportUserIDs = "initial_stock_import_user_ids"
  }

  private let defaults: UserDefaults
  private let secureStore: SecureStringStoring
  private let nowProvider: () -> Date

  init(
    defaults: UserDefaults = .standard,
    secureStore: SecureStringStoring? = nil,
    nowProvider: @escaping () -> Date = Date.init
  ) {
    self.defaults = defaults
    self.secureStore = secureStore
      ?? KeychainStringStore(service: Bundle.main.bundleIdentifier ?? "financeplan.auth")
    self.nowProvider = nowProvider
    migrateLegacyTokenStorageIfNeeded()
  }

  var authToken: String {
    get { persistedToken(for: Keys.authToken) ?? "" }
    set { setSecureValue(newValue, for: Keys.authToken) }
  }

  var refreshToken: String {
    get { persistedToken(for: Keys.refreshToken) ?? "" }
    set { setSecureValue(newValue, for: Keys.refreshToken) }
  }

  var authTokenExpiresAt: Date? {
    get { defaults.object(forKey: Keys.authTokenExpiresAt) as? Date }
    set { setDate(newValue, for: Keys.authTokenExpiresAt) }
  }

  var refreshTokenExpiresAt: Date? {
    get { defaults.object(forKey: Keys.refreshTokenExpiresAt) as? Date }
    set { setDate(newValue, for: Keys.refreshTokenExpiresAt) }
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

  var currentUserID: String {
    get { defaults.string(forKey: Keys.currentUserID) ?? "" }
    set { defaults.set(newValue, forKey: Keys.currentUserID) }
  }

  var currentUsername: String {
    get { defaults.string(forKey: Keys.currentUsername) ?? "" }
    set { defaults.set(newValue, forKey: Keys.currentUsername) }
  }

  func store(authResponse: AuthResponse) {
    authToken = authResponse.token
    refreshToken = authResponse.refreshToken
    currentUserID = authResponse.userId.uuidString

    let resolvedDisplayName = authResponse.username.trimmingCharacters(in: .whitespacesAndNewlines)
    if !resolvedDisplayName.isEmpty {
      currentUsername = resolvedDisplayName
    } else {
      let firstName = authResponse.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
      currentUsername = firstName.isEmpty ? authResponse.email : firstName
    }

    authTokenExpiresAt = JWTTokenInspector.expirationDate(in: authResponse.token)
      ?? nowProvider().addingTimeInterval(TimeInterval(authResponse.expiresIn))
    refreshTokenExpiresAt = nowProvider().addingTimeInterval(TimeInterval(authResponse.refreshExpiresIn))
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
    guard !userID.isEmpty else {
      return false
    }
    return initialStockImportUserIDs.contains(userID)
  }

  func markInitialStockImportCompleted(for userID: String) {
    guard !userID.isEmpty else {
      return
    }
    var allUserIDs = initialStockImportUserIDs
    allUserIDs.insert(userID)
    defaults.set(Array(allUserIDs), forKey: Keys.initialStockImportUserIDs)
  }

  private var initialStockImportUserIDs: Set<String> {
    Set(defaults.stringArray(forKey: Keys.initialStockImportUserIDs) ?? [])
  }

  private func setSecureValue(_ value: String, for key: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      secureStore.removeValue(for: key)
      defaults.removeObject(forKey: key)
    } else {
      secureStore.setString(trimmed, for: key)

      // Fall back to UserDefaults only when the secure store does not read back correctly.
      if secureStore.string(for: key) == trimmed {
        defaults.removeObject(forKey: key)
      } else {
        defaults.set(trimmed, forKey: key)
      }
    }
  }

  private func persistedToken(for key: String) -> String? {
    if let secureValue = secureStore.string(for: key),
       !secureValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return secureValue
    }

    if let fallbackValue = defaults.string(forKey: key),
       !fallbackValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return fallbackValue
    }

    return nil
  }

  private func setDate(_ value: Date?, for key: String) {
    if let value {
      defaults.set(value, forKey: key)
    } else {
      defaults.removeObject(forKey: key)
    }
  }

  private func migrateLegacyTokenStorageIfNeeded() {
    if secureStore.string(for: Keys.authToken) == nil,
       let legacyToken = defaults.string(forKey: Keys.authToken),
       !legacyToken.isEmpty {
      secureStore.setString(legacyToken, for: Keys.authToken)
      if secureStore.string(for: Keys.authToken) == legacyToken {
        defaults.removeObject(forKey: Keys.authToken)
      }
    }

    if secureStore.string(for: Keys.refreshToken) == nil,
       let legacyRefreshToken = defaults.string(forKey: Keys.refreshToken),
       !legacyRefreshToken.isEmpty {
      secureStore.setString(legacyRefreshToken, for: Keys.refreshToken)
      if secureStore.string(for: Keys.refreshToken) == legacyRefreshToken {
        defaults.removeObject(forKey: Keys.refreshToken)
      }
    }
  }
}
