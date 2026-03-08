import Combine
import Foundation
import StockPlanShared

@MainActor
final class LoginViewModel: ObservableObject {
  enum Field: Hashable {
    case username
    case password
    case email
    case firstName
    case lastName
  }


  @Published var username = ""
  @Published var password = ""
  @Published var email = ""
  @Published var firstName = ""
  @Published var lastName = ""
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

  private let authService: AuthServicing
  private let sessionStore: AuthSessionStoring
  private let onAuthenticated: () -> Void

  init(
    authService: AuthServicing,
    sessionStore: AuthSessionStoring,
    onAuthenticated: @escaping () -> Void = {}
  ) {
    self.authService = authService
    self.sessionStore = sessionStore
    self.onAuthenticated = onAuthenticated

    let storedIsSignup = sessionStore.loginIsSignup
    isSignup = storedIsSignup
    signupFieldsOpacity = storedIsSignup ? 1 : 0
  }

  func clearError() {
    error = nil
    infoMessage = nil
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
    isSignup = true
    signupFieldsOpacity = 1
    sessionStore.loginIsSignup = true
    error = nil
    infoMessage = nil
  }

  func hideSignup() {
    isSignup = false
    signupFieldsOpacity = 0
    sessionStore.loginIsSignup = false
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
      let auth = try await authService.login(
        email: username.trimmingCharacters(in: .whitespacesAndNewlines),
        password: password
      )
      persistAuth(auth)
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
        firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
        lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
        dateOfBirth: dateOfBirth
      )

      let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
      username = trimmedEmail
      password = ""
      hideSignup()
      infoMessage = "Account created. Please sign in."
      error = nil
    } catch {
      self.error = errorMessage(from: error, fallback: "Could not sign up. Please try again.")
    }
  }

  private func persistAuth(_ auth: AuthResponse) {
    sessionStore.store(authResponse: auth)
    onAuthenticated()
  }

  private func validateAllFields() {
    fieldErrors.removeAll()

    let fieldsToValidate: [Field] = isSignup
      ? [.username, .email, .firstName, .lastName, .password]
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
      if !AuthValidation.isValidPassword(password) {
        return "Password must be at least 8 characters"
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
    case .firstName:
      if isSignup, firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return "First name is required"
      }
    case .lastName:
      if isSignup, lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return "Last name is required"
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
