import Foundation
import StockPlanShared

protocol AuthServicing {
  func login(email: String, password: String) async throws -> AuthResponse
  func signup(
    username: String,
    email: String,
    password: String,
    confirmPassword: String,
    dateOfBirth: Date
  ) async throws
  func forgotPassword(email: String) async throws -> AuthForgotPasswordResponse
  func refresh(refreshToken: String) async throws -> AuthResponse
  func logout(refreshToken: String) async
  @MainActor
  func oauthSignIn(provider: OAuthProviderKind) async throws -> AuthResponse
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
  private let webAuthenticator: OAuthWebAuthenticating

  init(
    environmentManager: AppEnvironmentManager,
    session: AuthURLSessionProtocol = URLSession.shared,
    webAuthenticator: OAuthWebAuthenticating = OAuthWebAuthenticator()
  ) {
    self.environmentManager = environmentManager
    self.session = session
    self.webAuthenticator = webAuthenticator
  }

  func login(email: String, password: String) async throws -> AuthResponse {
    try await client().login(AuthLoginRequest(email: email, password: password))
  }

  func signup(
    username: String,
    email: String,
    password: String,
    confirmPassword: String,
    dateOfBirth: Date
  ) async throws {
    try await client().register(
      username: username,
      email: email,
      password: password,
      dateOfBirth: dateOfBirth,
      confirmPassword: confirmPassword
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

  @MainActor
  func oauthSignIn(provider: OAuthProviderKind) async throws -> AuthResponse {
    let callbackScheme = oauthCallbackScheme()
    let redirectURI = oauthRedirectURI(for: callbackScheme)

    let startResponse = try await client().oauthStart(
      provider: provider,
      redirectURI: redirectURI
    )

    guard let authorizationURL = URL(string: startResponse.authorizationURL) else {
      throw OAuthWebAuthenticationError.invalidAuthorizationURL
    }

    let callbackURL = try await webAuthenticator.authenticate(
      url: authorizationURL,
      callbackScheme: callbackScheme
    )

    let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
    guard let code = queryItems.first(where: { $0.name == "code" })?.value,
          !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw OAuthWebAuthenticationError.missingCode
    }
    guard let state = queryItems.first(where: { $0.name == "state" })?.value,
          !state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw OAuthWebAuthenticationError.missingState
    }

    return try await client().oauthExchange(
      provider: provider,
      request: OAuthExchangeRequestPayload(
        flowId: startResponse.flowId,
        code: code,
        state: state,
        redirectURI: redirectURI
      )
    )
  }

  private func client() -> AuthHTTPClient {
    AuthHTTPClient(baseURL: environmentManager.current.apiBaseUrl, session: session)
  }

  private func oauthCallbackScheme() -> String {
    let configured = (Bundle.main.object(forInfoDictionaryKey: "OAuthCallbackScheme") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if let configured, !configured.isEmpty {
      return configured
    }
    return "norviqa"
  }

  private func oauthRedirectURI(for callbackScheme: String) -> String {
    "\(callbackScheme)://oauth/callback"
  }
}

final class UserDefaultsAuthSessionStore: AuthSessionStoring {
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
  private let stateLock = NSRecursiveLock()
  private var didReportSecureStoreFailure = false

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
    get { withStateLock { secureToken(for: Keys.authToken) ?? "" } }
    set { withStateLock { setSecureValue(newValue, for: Keys.authToken) } }
  }

  var refreshToken: String {
    get { withStateLock { secureToken(for: Keys.refreshToken) ?? "" } }
    set { withStateLock { setSecureValue(newValue, for: Keys.refreshToken) } }
  }

  var authTokenExpiresAt: Date? {
    get { withStateLock { defaults.object(forKey: Keys.authTokenExpiresAt) as? Date } }
    set { withStateLock { setDate(newValue, for: Keys.authTokenExpiresAt) } }
  }

  var refreshTokenExpiresAt: Date? {
    get { withStateLock { defaults.object(forKey: Keys.refreshTokenExpiresAt) as? Date } }
    set { withStateLock { setDate(newValue, for: Keys.refreshTokenExpiresAt) } }
  }

  var loginIsSignup: Bool {
    get { withStateLock {
      if defaults.object(forKey: Keys.loginIsSignup) == nil {
        return true
      }
      return defaults.bool(forKey: Keys.loginIsSignup)
    } }
    set { withStateLock { defaults.set(newValue, forKey: Keys.loginIsSignup) } }
  }

  var currentUserID: String {
    get { withStateLock { defaults.string(forKey: Keys.currentUserID) ?? "" } }
    set { withStateLock { defaults.set(newValue, forKey: Keys.currentUserID) } }
  }

  var currentUsername: String {
    get { withStateLock { defaults.string(forKey: Keys.currentUsername) ?? "" } }
    set { withStateLock { defaults.set(newValue, forKey: Keys.currentUsername) } }
  }

  func store(authResponse: AuthResponse) {
    withStateLock {
      authToken = authResponse.token
      refreshToken = authResponse.refreshToken
      guard !didReportSecureStoreFailure else {
        return
      }
      currentUserID = authResponse.userId.uuidString
      currentUsername = authResponse.username.trimmingCharacters(in: .whitespacesAndNewlines)

      authTokenExpiresAt = JWTTokenInspector.expirationDate(in: authResponse.token)
        ?? nowProvider().addingTimeInterval(TimeInterval(authResponse.expiresIn))
      refreshTokenExpiresAt = nowProvider().addingTimeInterval(TimeInterval(authResponse.refreshExpiresIn))
    }
  }

  func clearSession() {
    withStateLock {
      didReportSecureStoreFailure = false
      authToken = ""
      refreshToken = ""
      authTokenExpiresAt = nil
      refreshTokenExpiresAt = nil
      currentUserID = ""
      currentUsername = ""
    }
  }

  func hasCompletedInitialStockImport(for userID: String) -> Bool {
    guard !userID.isEmpty else {
      return false
    }
    return withStateLock { initialStockImportUserIDs.contains(userID) }
  }

  func markInitialStockImportCompleted(for userID: String) {
    guard !userID.isEmpty else {
      return
    }
    withStateLock {
      var allUserIDs = initialStockImportUserIDs
      allUserIDs.insert(userID)
      defaults.set(Array(allUserIDs), forKey: Keys.initialStockImportUserIDs)
    }
  }

  private var initialStockImportUserIDs: Set<String> {
    Set(defaults.stringArray(forKey: Keys.initialStockImportUserIDs) ?? [])
  }

  @inline(__always)
  private func withStateLock<T>(_ operation: () throws -> T) rethrows -> T {
    stateLock.lock()
    defer { stateLock.unlock() }
    return try operation()
  }

  private func setSecureValue(_ value: String, for key: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      do {
        try secureStore.removeValue(for: key)
      } catch {
        handleSecureStoreFailure(error)
      }
      defaults.removeObject(forKey: key)
    } else {
      do {
        try secureStore.setString(trimmed, for: key)
        defaults.removeObject(forKey: key)
      } catch {
        handleSecureStoreFailure(error)
      }
    }
  }

  private func secureToken(for key: String) -> String? {
    do {
      if let secureValue = try secureStore.string(for: key),
       !secureValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return secureValue
      }
    } catch {
      handleSecureStoreFailure(error)
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
    if let legacyToken = defaults.string(forKey: Keys.authToken),
       !legacyToken.isEmpty {
      do {
        if try secureStore.string(for: Keys.authToken) == nil {
          try secureStore.setString(legacyToken, for: Keys.authToken)
        }
      } catch {
        handleSecureStoreFailure(error)
      }
      defaults.removeObject(forKey: Keys.authToken)
    }

    if let legacyRefreshToken = defaults.string(forKey: Keys.refreshToken),
       !legacyRefreshToken.isEmpty {
      do {
        if try secureStore.string(for: Keys.refreshToken) == nil {
          try secureStore.setString(legacyRefreshToken, for: Keys.refreshToken)
        }
      } catch {
        handleSecureStoreFailure(error)
      }
      defaults.removeObject(forKey: Keys.refreshToken)
    }
  }

  private func handleSecureStoreFailure(_ error: Error) {
    let shouldNotify: Bool = withStateLock {
      authTokenExpiresAt = nil
      refreshTokenExpiresAt = nil
      currentUserID = ""
      currentUsername = ""
      defaults.removeObject(forKey: Keys.authToken)
      defaults.removeObject(forKey: Keys.refreshToken)

      guard !didReportSecureStoreFailure else {
        return false
      }
      didReportSecureStoreFailure = true
      return true
    }

    guard shouldNotify else { return }
    Task { @MainActor in
      NotificationCenter.default.post(
        name: .authSessionStorageFailure,
        object: nil,
        userInfo: ["error": String(describing: error)]
      )
    }
  }
}
