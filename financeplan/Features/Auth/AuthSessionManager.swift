import Foundation
import StockPlanShared

extension Notification.Name {
  static let authSessionWillInvalidate = Notification.Name("authSessionWillInvalidate")
  static let authSessionDidInvalidate = Notification.Name("authSessionDidInvalidate")
  static let authSessionStorageFailure = Notification.Name("authSessionStorageFailure")
}

enum AuthSessionError: LocalizedError, Equatable {
  case notAuthenticated
  case sessionExpired

  var errorDescription: String? {
    switch self {
    case .notAuthenticated, .sessionExpired:
      return "Your session expired. Please sign in again."
    }
  }
}

protocol AuthSessionManaging: AnyObject {
  func restoreSessionIfNeeded() async -> Bool
  func validAccessToken() async throws -> String?
  func refreshAccessToken() async throws -> String?
  func logout() async
  func invalidateSession() async
}

final class AuthSessionManager: AuthSessionManaging {
  private let authService: AuthServicing
  private let sessionStore: AuthSessionStoring
  private let nowProvider: () -> Date
  private let refreshLeeway: TimeInterval
  private let refreshTaskLock = NSLock()

  private var refreshTask: Task<String?, Error>?
  private var refreshTaskID: UUID?

  init(
    authService: AuthServicing,
    sessionStore: AuthSessionStoring,
    nowProvider: @escaping () -> Date = Date.init,
    refreshLeeway: TimeInterval = 10
  ) {
    self.authService = authService
    self.sessionStore = sessionStore
    self.nowProvider = nowProvider
    self.refreshLeeway = refreshLeeway
  }

  func restoreSessionIfNeeded() async -> Bool {
    do {
      let token = try await validAccessToken()
      return !(token?.isEmpty ?? true)
    } catch {
      return false
    }
  }

  func validAccessToken() async throws -> String? {
    let now = nowProvider()
    let token = trimmed(sessionStore.authToken)

    if !token.isEmpty {
      syncClaimsIfPossible(from: token)

      guard let expiry = accessTokenExpiry(for: token) else {
        return token
      }

      let remainingLifetime = expiry.timeIntervalSince(now)
      if remainingLifetime > refreshLeeway {
        return token
      }

      if remainingLifetime > 0 {
        guard hasUsableRefreshToken(now: now) else {
          return token
        }

        do {
          return try await refreshAccessToken(clearSessionOnFailure: false)
        } catch {
          return token
        }
      }

      if hasUsableRefreshToken(now: now) {
        return try await refreshAccessToken()
      }

      clearSession(notify: true)
      throw AuthSessionError.sessionExpired
    }

    if hasUsableRefreshToken(now: now) {
      return try await refreshAccessToken()
    }

    if !trimmed(sessionStore.refreshToken).isEmpty {
      clearSession(notify: true)
      throw AuthSessionError.sessionExpired
    }

    return nil
  }

  func refreshAccessToken() async throws -> String? {
    try await refreshAccessToken(clearSessionOnFailure: true)
  }

  private func refreshAccessToken(clearSessionOnFailure: Bool) async throws -> String? {
    let now = nowProvider()
    guard hasUsableRefreshToken(now: now) else {
      if clearSessionOnFailure {
        clearSession(notify: true)
      }
      throw AuthSessionError.notAuthenticated
    }

    if let task = currentRefreshTask() {
      return try await task.value
    }

    let refreshID = UUID()
    let task = Task<String?, Error> { [weak self] in
      guard let self else { return nil }

      let refreshToken = self.trimmed(self.sessionStore.refreshToken)
      guard !refreshToken.isEmpty else {
        if clearSessionOnFailure {
          self.clearSession(notify: true)
        }
        throw AuthSessionError.notAuthenticated
      }

      let response = try await self.authService.refresh(refreshToken: refreshToken)
      self.sessionStore.store(authResponse: response)
      self.syncClaimsIfPossible(from: response.token)
      return self.trimmed(self.sessionStore.authToken)
    }

    setRefreshTask(task, id: refreshID)
    defer { clearRefreshTask(id: refreshID) }

    do {
      return try await task.value
    } catch {
      if clearSessionOnFailure {
        clearSession(notify: true)
      }
      throw error
    }
  }

  func logout() async {
    NotificationCenter.default.post(name: .authSessionWillInvalidate, object: nil)
    await authService.logout(refreshToken: sessionStore.refreshToken)
    clearSession(notify: true)
  }

  func invalidateSession() async {
    NotificationCenter.default.post(name: .authSessionWillInvalidate, object: nil)
    clearSession(notify: true)
  }

  private func accessTokenExpiry(for token: String) -> Date? {
    JWTTokenInspector.expirationDate(in: token) ?? sessionStore.authTokenExpiresAt
  }

  private func hasUsableRefreshToken(now: Date) -> Bool {
    let refreshToken = trimmed(sessionStore.refreshToken)
    guard !refreshToken.isEmpty else {
      return false
    }

    guard let expiry = sessionStore.refreshTokenExpiresAt else {
      return true
    }

    return expiry > now
  }

  private func syncClaimsIfPossible(from token: String) {
    if sessionStore.currentUserID.isEmpty,
       let userID = JWTTokenInspector.userID(in: token) {
      sessionStore.currentUserID = userID.uuidString
    }

    if sessionStore.authTokenExpiresAt == nil,
       let expiry = JWTTokenInspector.expirationDate(in: token) {
      sessionStore.authTokenExpiresAt = expiry
    }
  }

  private func clearSession(notify: Bool) {
    sessionStore.clearSession()

    guard notify else {
      return
    }

    Task { @MainActor in
      NotificationCenter.default.post(name: .authSessionDidInvalidate, object: nil)
    }
  }

  private func trimmed(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func currentRefreshTask() -> Task<String?, Error>? {
    refreshTaskLock.lock()
    defer { refreshTaskLock.unlock() }
    return refreshTask
  }

  private func setRefreshTask(_ task: Task<String?, Error>, id: UUID) {
    refreshTaskLock.lock()
    defer { refreshTaskLock.unlock() }
    refreshTask = task
    refreshTaskID = id
  }

  private func clearRefreshTask(id: UUID) {
    refreshTaskLock.lock()
    defer { refreshTaskLock.unlock() }

    guard refreshTaskID == id else {
      return
    }

    refreshTask = nil
    refreshTaskID = nil
  }
}
