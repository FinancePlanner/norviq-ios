import Foundation
import StockPlanShared

protocol AuthServicing: Sendable {
  func login(email: String, password: String) async throws -> AuthLoginOutcomePayload
  func signup(
    username: String,
    email: String,
    password: String,
    confirmPassword: String,
    dateOfBirth: Date
  ) async throws
  func forgotPassword(email: String) async throws -> AuthForgotPasswordResponse
  func verifyMFA(challengeId: UUID, code: String) async throws -> AuthResponse
  func resendMFA(challengeId: UUID) async throws -> AuthMFAChallengeResponsePayload
  func refresh(refreshToken: String) async throws -> AuthResponse
  func logout(refreshToken: String) async
  @MainActor
  func oauthSignIn(provider: OAuthProviderKind) async throws -> AuthLoginOutcomePayload
}

protocol AuthSessionStoring: Sendable {
  var authToken: String { get async }
  func setAuthToken(_ value: String) async

  var refreshToken: String { get async }
  func setRefreshToken(_ value: String) async

  var authTokenExpiresAt: Date? { get async }
  func setAuthTokenExpiresAt(_ value: Date?) async

  var refreshTokenExpiresAt: Date? { get async }
  func setRefreshTokenExpiresAt(_ value: Date?) async

  var loginIsSignup: Bool { get async }
  func setLoginIsSignup(_ value: Bool) async

  var currentUserID: String { get async }
  func setCurrentUserID(_ value: String) async

  var currentUsername: String { get async }
  func setCurrentUsername(_ value: String) async

  func store(authResponse: AuthResponse) async
  func clearSession() async
  func hasCompletedInitialStockImport(for userID: String) async -> Bool
  func markInitialStockImportCompleted(for userID: String) async
  func hasCompletedOnboardingQuestionnaire(for userID: String) async -> Bool
  func markOnboardingQuestionnaireCompleted(for userID: String) async
  func requiresOnboardingQuestionnaire(for userID: String) async -> Bool
  func markOnboardingQuestionnaireRequired(for userID: String) async
  func markPendingOnboardingAfterSignup(email: String) async
  func hasPendingOnboardingAfterSignup(email: String) async -> Bool
  func clearPendingOnboardingAfterSignup(email: String) async
}

final class AuthService: AuthServicing, @unchecked Sendable {
  private let environmentManager: AppEnvironmentManager
  private let session: any HTTPClientSession
  private let webAuthenticator: OAuthWebAuthenticating

  init(
    environmentManager: AppEnvironmentManager,
    session: any HTTPClientSession = URLSession.shared,
    webAuthenticator: OAuthWebAuthenticating = OAuthWebAuthenticator()
  ) {
    self.environmentManager = environmentManager
    self.session = session
    self.webAuthenticator = webAuthenticator
  }

  func login(email: String, password: String) async throws -> AuthLoginOutcomePayload {
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

  func verifyMFA(challengeId: UUID, code: String) async throws -> AuthResponse {
    try await client().verifyMFA(
      AuthMFAVerifyRequestPayload(challengeId: challengeId, code: code)
    )
  }

  func resendMFA(challengeId: UUID) async throws -> AuthMFAChallengeResponsePayload {
    try await client().resendMFA(
      AuthMFAResendRequestPayload(challengeId: challengeId)
    )
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
  func oauthSignIn(provider: OAuthProviderKind) async throws -> AuthLoginOutcomePayload {
    let callbackScheme = oauthCallbackScheme(for: provider)
    let redirectURI = oauthRedirectURI(for: provider, callbackScheme: callbackScheme)

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

  private func oauthCallbackScheme(for provider: OAuthProviderKind) -> String {
    if provider == .google, let reversed = googleReversedClientID() {
      return reversed
    }
    let configured = (Bundle.main.object(forInfoDictionaryKey: "OAuthCallbackScheme") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if let configured, !configured.isEmpty {
      return configured
    }
    return "norviqa"
  }

  private func oauthRedirectURI(for provider: OAuthProviderKind, callbackScheme: String) -> String {
    if provider == .google {
      return "\(callbackScheme):/oauth2redirect"
    }
    if (provider == .x || provider == .apple), let bridge = httpsBridgeURL(for: provider) {
      return bridge
    }
    return "\(callbackScheme)://oauth/callback"
  }

  private func httpsBridgeURL(for provider: OAuthProviderKind) -> String? {
    let host = environmentManager.current.apiBaseUrl.absoluteString
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return "\(host)/v1/auth/oauth/\(provider.rawValue)/callback"
  }

  private func googleReversedClientID() -> String? {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientID") as? String else {
      return nil
    }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let suffix = ".apps.googleusercontent.com"
    let prefix: String
    if trimmed.hasSuffix(suffix) {
      prefix = String(trimmed.dropLast(suffix.count))
    } else {
      prefix = trimmed
    }
    return "com.googleusercontent.apps.\(prefix)"
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
    static let onboardingQuestionnaireCompletedUserIDs = "onboarding_questionnaire_completed_user_ids"
    static let onboardingQuestionnaireRequiredUserIDs = "onboarding_questionnaire_required_user_ids"
    static let pendingOnboardingSignupEmails = "pending_onboarding_signup_emails"
  }

  private let defaults: UserDefaults
  private let secureStore: SecureStringStoring
  private let nowProvider: @Sendable () -> Date
  private var didReportSecureStoreFailure = false

  init(
    defaults: UserDefaults = .standard,
    secureStore: SecureStringStoring? = nil,
    nowProvider: @escaping @Sendable () -> Date = Date.init
  ) {
    self.defaults = defaults
    self.secureStore = secureStore
      ?? KeychainStringStore(service: Bundle.main.bundleIdentifier ?? "financeplan.auth")
    self.nowProvider = nowProvider
    migrateLegacyTokenStorageIfNeeded()
  }

  var authToken: String {
    secureToken(for: Keys.authToken) ?? ""
  }

  func setAuthToken(_ value: String) {
    setSecureValue(value, for: Keys.authToken)
  }

  var refreshToken: String {
    secureToken(for: Keys.refreshToken) ?? ""
  }

  func setRefreshToken(_ value: String) {
    setSecureValue(value, for: Keys.refreshToken)
  }

  var authTokenExpiresAt: Date? {
    defaults.object(forKey: Keys.authTokenExpiresAt) as? Date
  }

  func setAuthTokenExpiresAt(_ value: Date?) {
    setDate(value, for: Keys.authTokenExpiresAt)
  }

  var refreshTokenExpiresAt: Date? {
    defaults.object(forKey: Keys.refreshTokenExpiresAt) as? Date
  }

  func setRefreshTokenExpiresAt(_ value: Date?) {
    setDate(value, for: Keys.refreshTokenExpiresAt)
  }

  var loginIsSignup: Bool {
    if defaults.object(forKey: Keys.loginIsSignup) == nil {
      return true
    }
    return defaults.bool(forKey: Keys.loginIsSignup)
  }

  func setLoginIsSignup(_ value: Bool) {
    defaults.set(value, forKey: Keys.loginIsSignup)
  }

  var currentUserID: String {
    defaults.string(forKey: Keys.currentUserID) ?? ""
  }

  func setCurrentUserID(_ value: String) {
    defaults.set(value, forKey: Keys.currentUserID)
  }

  var currentUsername: String {
    defaults.string(forKey: Keys.currentUsername) ?? ""
  }

  func setCurrentUsername(_ value: String) {
    defaults.set(value, forKey: Keys.currentUsername)
  }

  func store(authResponse: AuthResponse) {
    setAuthToken(authResponse.token)
    setRefreshToken(authResponse.refreshToken)
    guard !didReportSecureStoreFailure else {
      return
    }
    setCurrentUserID(authResponse.userId.uuidString)
    setCurrentUsername(authResponse.username.trimmingCharacters(in: .whitespacesAndNewlines))

    setAuthTokenExpiresAt(JWTTokenInspector.expirationDate(in: authResponse.token)
      ?? nowProvider().addingTimeInterval(TimeInterval(authResponse.expiresIn)))
    setRefreshTokenExpiresAt(nowProvider().addingTimeInterval(TimeInterval(authResponse.refreshExpiresIn)))
  }

  func clearSession() {
    didReportSecureStoreFailure = false
    setAuthToken("")
    setRefreshToken("")
    setAuthTokenExpiresAt(nil)
    setRefreshTokenExpiresAt(nil)
    setCurrentUserID("")
    setCurrentUsername("")
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

  func hasCompletedOnboardingQuestionnaire(for userID: String) -> Bool {
    let normalizedUserID = normalizedUserID(userID)
    guard !normalizedUserID.isEmpty else {
      return false
    }
    return onboardingQuestionnaireCompletedUserIDs.contains(normalizedUserID)
  }

  func markOnboardingQuestionnaireCompleted(for userID: String) {
    let normalizedUserID = normalizedUserID(userID)
    guard !normalizedUserID.isEmpty else {
      return
    }
    var completedUserIDs = onboardingQuestionnaireCompletedUserIDs
    completedUserIDs.insert(normalizedUserID)
    defaults.set(Array(completedUserIDs), forKey: Keys.onboardingQuestionnaireCompletedUserIDs)

    var requiredUserIDs = onboardingQuestionnaireRequiredUserIDs
    requiredUserIDs.remove(normalizedUserID)
    defaults.set(Array(requiredUserIDs), forKey: Keys.onboardingQuestionnaireRequiredUserIDs)
  }

  func requiresOnboardingQuestionnaire(for userID: String) -> Bool {
    let normalizedUserID = normalizedUserID(userID)
    guard !normalizedUserID.isEmpty else {
      return false
    }
    return onboardingQuestionnaireRequiredUserIDs.contains(normalizedUserID)
      && !onboardingQuestionnaireCompletedUserIDs.contains(normalizedUserID)
  }

  func markOnboardingQuestionnaireRequired(for userID: String) {
    let normalizedUserID = normalizedUserID(userID)
    guard !normalizedUserID.isEmpty,
          !onboardingQuestionnaireCompletedUserIDs.contains(normalizedUserID) else {
      return
    }
    var requiredUserIDs = onboardingQuestionnaireRequiredUserIDs
    requiredUserIDs.insert(normalizedUserID)
    defaults.set(Array(requiredUserIDs), forKey: Keys.onboardingQuestionnaireRequiredUserIDs)
  }

  func markPendingOnboardingAfterSignup(email: String) {
    let normalizedEmail = normalizedEmail(email)
    guard !normalizedEmail.isEmpty else {
      return
    }
    var emails = pendingOnboardingSignupEmails
    emails.insert(normalizedEmail)
    defaults.set(Array(emails), forKey: Keys.pendingOnboardingSignupEmails)
  }

  func hasPendingOnboardingAfterSignup(email: String) -> Bool {
    let normalizedEmail = normalizedEmail(email)
    guard !normalizedEmail.isEmpty else {
      return false
    }
    return pendingOnboardingSignupEmails.contains(normalizedEmail)
  }

  func clearPendingOnboardingAfterSignup(email: String) {
    let normalizedEmail = normalizedEmail(email)
    guard !normalizedEmail.isEmpty else {
      return
    }
    var emails = pendingOnboardingSignupEmails
    emails.remove(normalizedEmail)
    defaults.set(Array(emails), forKey: Keys.pendingOnboardingSignupEmails)
  }

  private var initialStockImportUserIDs: Set<String> {
    Set(defaults.stringArray(forKey: Keys.initialStockImportUserIDs) ?? [])
  }

  private var onboardingQuestionnaireCompletedUserIDs: Set<String> {
    Set(defaults.stringArray(forKey: Keys.onboardingQuestionnaireCompletedUserIDs) ?? [])
  }

  private var onboardingQuestionnaireRequiredUserIDs: Set<String> {
    Set(defaults.stringArray(forKey: Keys.onboardingQuestionnaireRequiredUserIDs) ?? [])
  }

  private var pendingOnboardingSignupEmails: Set<String> {
    Set(defaults.stringArray(forKey: Keys.pendingOnboardingSignupEmails) ?? [])
  }

  private func normalizedUserID(_ userID: String) -> String {
    userID.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func normalizedEmail(_ email: String) -> String {
    email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
    setAuthTokenExpiresAt(nil)
    setRefreshTokenExpiresAt(nil)
    setCurrentUserID("")
    setCurrentUsername("")
    defaults.removeObject(forKey: Keys.authToken)
    defaults.removeObject(forKey: Keys.refreshToken)

    guard !didReportSecureStoreFailure else {
      return
    }
    didReportSecureStoreFailure = true

    let errorDescription = String(describing: error)
    Task { @MainActor in
      NotificationCenter.default.post(
        name: .authSessionStorageFailure,
        object: nil,
        userInfo: ["error": errorDescription]
      )
    }
  }
}
