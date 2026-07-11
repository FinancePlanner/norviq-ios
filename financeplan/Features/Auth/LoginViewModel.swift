import Combine
import Foundation
import PostHog
import Sentry
import StockPlanShared

@MainActor
final class LoginViewModel: ObservableObject {
  enum Field: Hashable {
    case username
    case password
    case confirmPassword
    case email
  }

  @Published var username = ""
  @Published var password = ""
  @Published var confirmPassword = ""
  @Published var email = ""
  @Published var dateOfBirth = {
    let calendar = Calendar.current
    let currentYear = calendar.component(.year, from: Date())
    let twentyYearsAgoYear = currentYear - 20
    return calendar.date(from: DateComponents(year: twentyYearsAgoYear, month: 1, day: 1)) ?? Date()
  }()

  @Published var isSignup: Bool
  @Published var error: String?
  @Published var infoMessage: String?
  @Published var fieldErrors: [Field: String] = [:]
  @Published var hasAttemptedSubmission = false
  @Published var signupFieldsOpacity: Double
  @Published var isForgotPasswordPresented = false
  @Published var isSubmitting = false
  @Published var pendingMFAChallenge: AuthMFAChallengeResponsePayload?
  @Published var mfaCode = ""
  @Published var mfaError: String?
  @Published var mfaInfoMessage: String?
  @Published var mfaResendAvailableIn = 0
  @Published var isVerifyingMFA = false
  @Published var isResendingMFA = false

  var passwordRuleScore: Int {
    AuthValidation.passwordRuleScore(password)
  }

  var passwordStrength: AuthValidation.PasswordStrength {
    AuthValidation.passwordStrength(password)
  }

  var canSubmitSignup: Bool {
    let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
    return AuthValidation.isValidUsername(trimmedUsername)
      && AuthValidation.isValidEmail(trimmedEmail)
      && AuthValidation.isStrongPassword(password)
      && !confirmPassword.isEmpty
      && password == confirmPassword
  }

  private let authService: AuthServicing
  private let sessionStore: AuthSessionStoring
  private let onAuthenticated: () -> Void
  private var mfaCountdownTask: Task<Void, Never>?

  init(
    authService: AuthServicing,
    sessionStore: AuthSessionStoring,
    onAuthenticated: @escaping () -> Void = {}
  ) {
    self.authService = authService
    self.sessionStore = sessionStore
    self.onAuthenticated = onAuthenticated

    self.isSignup = false
    self.signupFieldsOpacity = 0
    
    Task {
      let storedIsSignup = await sessionStore.loginIsSignup
      self.isSignup = storedIsSignup
      self.signupFieldsOpacity = storedIsSignup ? 1 : 0
    }
  }

  deinit {
    mfaCountdownTask?.cancel()
  }

  func clearError() {
    error = nil
    infoMessage = nil
    mfaError = nil
    mfaInfoMessage = nil
  }

  func clearFieldError(_ field: Field) {
    if hasAttemptedSubmission {
      fieldErrors.removeValue(forKey: field)
    }
  }

  func sanitizeUsernameInput(_ newValue: String) {
    guard isSignup else {
      return
    }

    let filtered = newValue.filter { $0.isLetter || $0.isNumber || $0 == "_" }.prefix(30)
    let normalized = String(filtered)
    if normalized != newValue {
      username = normalized
    }
  }

  func showSignup() {
    dismissMFAFlow()
    isSignup = true
    signupFieldsOpacity = 1
    Task {
      await sessionStore.setLoginIsSignup(true)
    }
    error = nil
    infoMessage = nil
  }

  func hideSignup() {
    dismissMFAFlow()
    isSignup = false
    signupFieldsOpacity = 0
    Task {
      await sessionStore.setLoginIsSignup(false)
    }
    confirmPassword = ""
    error = nil
    infoMessage = nil
  }

  func submit() async {
    guard !isSubmitting else {
      return
    }

    if isSignup {
      await signup()
    } else {
      await login()
    }
  }

  func requestForgotPassword(for submittedEmail: String) async throws -> String {
    let response = try await authService.forgotPassword(
      email: submittedEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    )
    return response.message
  }

  func dismissMFAFlow() {
    pendingMFAChallenge = nil
    mfaCode = ""
    mfaError = nil
    mfaInfoMessage = nil
    mfaResendAvailableIn = 0
    isVerifyingMFA = false
    isResendingMFA = false
    mfaCountdownTask?.cancel()
    mfaCountdownTask = nil
  }

  func submitMFA() async {
    guard !isVerifyingMFA else {
      return
    }
    guard let challenge = pendingMFAChallenge else {
      return
    }

    let trimmed = mfaCode.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.range(of: #"^[0-9]{6}$"#, options: .regularExpression) != nil else {
      mfaError = "Enter the 6-digit verification code."
      return
    }

    mfaError = nil
    mfaInfoMessage = nil
    isVerifyingMFA = true
    defer { isVerifyingMFA = false }

    do {
      let auth = try await authService.verifyMFA(challengeId: challenge.challengeId, code: trimmed)
      await persistAuth(auth)
      dismissMFAFlow()
      error = nil
    } catch {
      mfaError = errorMessage(from: error, fallback: "Could not verify code. Please try again.")
    }
  }

  func resendMFA() async {
    guard !isResendingMFA else {
      return
    }
    guard mfaResendAvailableIn == 0 else {
      return
    }
    guard let challenge = pendingMFAChallenge else {
      return
    }

    mfaError = nil
    mfaInfoMessage = nil
    isResendingMFA = true
    defer { isResendingMFA = false }

    do {
      let refreshed = try await authService.resendMFA(challengeId: challenge.challengeId)
      pendingMFAChallenge = refreshed
      mfaCode = ""
      startMFAResendCountdown(seconds: refreshed.resendAvailableIn)
      mfaInfoMessage = "A new code has been sent."
    } catch {
      mfaError = errorMessage(from: error, fallback: "Could not resend code right now.")
    }
  }

  func signInWithOAuth(_ provider: OAuthProviderKind) async {
    guard !isSubmitting else {
      return
    }

    error = nil
    infoMessage = nil
    isSubmitting = true
    defer { isSubmitting = false }

    do {
      let outcome = try await authService.oauthSignIn(provider: provider)
      try await handleAuthOutcome(
        outcome,
        fallbackOnMissingPayload: "Could not complete sign in. Please try again."
      )
      error = nil
    } catch {
      self.error = errorMessage(from: error, fallback: "Could not sign in with \(provider.rawValue.capitalized). Please try again.")
    }
  }

  private func login() async {
    hasAttemptedSubmission = true
    validateAllFields()
    guard fieldErrors.isEmpty else {
      return
    }

    error = nil
    infoMessage = nil
    isSubmitting = true
    defer { isSubmitting = false }

    do {
      let outcome = try await authService.login(
        email: username.trimmingCharacters(in: .whitespacesAndNewlines),
        password: password
      )
      try await handleAuthOutcome(
        outcome,
        fallbackOnMissingPayload: "Could not complete sign in. Please try again."
      )
      error = nil
    } catch {
      self.error = errorMessage(from: error, fallback: "Could not log in. Please try again.")
    }
  }

  private func signup() async {
    hasAttemptedSubmission = true
    validateAllFields()
    guard fieldErrors.isEmpty else {
      return
    }

    error = nil
    infoMessage = nil
    isSubmitting = true
    defer { isSubmitting = false }

    do {
      try await authService.signup(
        username: username.trimmingCharacters(in: .whitespacesAndNewlines),
        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
        password: password,
        confirmPassword: confirmPassword,
        dateOfBirth: dateOfBirth
      )

      let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
      await sessionStore.markPendingOnboardingAfterSignup(email: trimmedEmail)
      // PostHog: Track new account creation
      PostHogSDK.shared.capture("user_signed_up", properties: [
        "username": username.trimmingCharacters(in: .whitespacesAndNewlines),
      ])
      username = trimmedEmail
      password = ""
      confirmPassword = ""
      hideSignup()
      infoMessage = "Account created. Please sign in."
      error = nil
    } catch {
      self.error = errorMessage(from: error, fallback: "Could not sign up. Please try again.")
    }
  }

  private func persistAuth(_ auth: AuthResponse) async {
    await sessionStore.store(authResponse: auth)
    let userId = auth.userId.uuidString
    let username = auth.username.trimmingCharacters(in: .whitespacesAndNewlines)
    if await sessionStore.hasPendingOnboardingAfterSignup(email: auth.email) {
      await sessionStore.markOnboardingQuestionnaireRequired(for: userId)
      await sessionStore.clearPendingOnboardingAfterSignup(email: auth.email)
    }
    // Sentry: attach user to crash reports
    let sentryUser = Sentry.User(userId: userId)
    sentryUser.username = username
    SentrySDK.setUser(sentryUser)
    // PostHog: Identify user and track login
    PostHogSDK.shared.identify(userId, userProperties: [
      "username": username,
    ])
    PostHogSDK.shared.capture("user_logged_in", properties: [
      "username": username,
    ])
    onAuthenticated()
  }

  private func handleAuthOutcome(
    _ outcome: AuthLoginOutcomePayload,
    fallbackOnMissingPayload: String
  ) async throws {
    switch outcome.status {
    case .authenticated:
      guard let auth = outcome.auth else {
        throw AuthHTTPClient.Error.api(fallbackOnMissingPayload)
      }
      dismissMFAFlow()
      await persistAuth(auth)
    case .mfaRequired:
      guard let challenge = outcome.mfa else {
        throw AuthHTTPClient.Error.api(fallbackOnMissingPayload)
      }
      pendingMFAChallenge = challenge
      mfaCode = ""
      mfaError = nil
      mfaInfoMessage = nil
      startMFAResendCountdown(seconds: challenge.resendAvailableIn)
    }
  }

  private func startMFAResendCountdown(seconds: Int) {
    mfaCountdownTask?.cancel()
    mfaResendAvailableIn = max(0, seconds)
    guard mfaResendAvailableIn > 0 else {
      return
    }

    mfaCountdownTask = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled && self.mfaResendAvailableIn > 0 {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        if Task.isCancelled { return }
        self.mfaResendAvailableIn = max(0, self.mfaResendAvailableIn - 1)
      }
    }
  }

  private func validateAllFields() {
    fieldErrors.removeAll()

    let fieldsToValidate: [Field] = isSignup
      ? [.username, .email, .password, .confirmPassword]
      : [.username, .password]

    for field in fieldsToValidate {
      if let message = validateField(field) {
        fieldErrors[field] = message
      }
    }
  }

  private func validateField(_ field: Field) -> String? {
    switch field {
    case .username:
      if username.isEmpty {
        return isSignup ? "Username is required" : "Email is required"
      }
      if isSignup, !AuthValidation.isValidUsername(username) {
        return "Username must be 4-30 characters (letters, numbers, underscore)"
      }
      if !isSignup, !AuthValidation.isValidEmail(username) {
        return "Please enter a valid email address"
      }
    case .password:
      if password.isEmpty {
        return "Password is required"
      }
      if isSignup && !AuthValidation.isStrongPassword(password) {
        return "Password must be at least 8 characters and include uppercase, lowercase, number, and symbol"
      }
      if !isSignup && !AuthValidation.isValidPassword(password) {
        return "Password must be at least 8 characters"
      }
    case .confirmPassword:
      if isSignup {
        if confirmPassword.isEmpty {
          return "Confirm password is required"
        }
        if password != confirmPassword {
          return "Passwords do not match"
        }
      }
    case .email:
      if isSignup {
        if email.isEmpty {
          return "Email is required"
        }
        if !AuthValidation.isValidEmail(email) {
          return "Please enter a valid email address"
        }
      }
    }

    return nil
  }

  private func errorMessage(from error: Error, fallback: String) -> String {
    if let authError = error as? AuthHTTPClient.Error, let description = authError.errorDescription {
      return description
    }
    if let localized = error as? LocalizedError, let description = localized.errorDescription, !description.isEmpty {
      return description
    }
    return fallback
  }
}
