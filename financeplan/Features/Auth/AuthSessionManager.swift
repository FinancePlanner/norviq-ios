import Foundation
import StockPlanShared

extension Notification.Name {
  nonisolated static let authSessionWillInvalidate = Notification.Name("authSessionWillInvalidate")
  nonisolated static let authSessionDidInvalidate = Notification.Name("authSessionDidInvalidate")
  nonisolated static let authSessionStorageFailure = Notification.Name("authSessionStorageFailure")
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

protocol AuthSessionManaging: Sendable {
  func restoreSessionIfNeeded() async -> Bool
  func validAccessToken() async throws -> String?
  func refreshAccessToken() async throws -> String?
  func logout() async
  func invalidateSession() async
}

final class AuthSessionManager: AuthSessionManaging, @unchecked Sendable {
  private let authService: AuthServicing
  private let sessionStore: AuthSessionStoring
  private let nowProvider: @Sendable () -> Date
  private let refreshLeeway: TimeInterval

  private var refreshTask: Task<String?, Error>?
  private var refreshTaskID: UUID?

  init(
    authService: AuthServicing,
    sessionStore: AuthSessionStoring,
    nowProvider: @escaping @Sendable () -> Date = Date.init,
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
    let token = trimmed(await sessionStore.authToken)

    if !token.isEmpty {
      await syncClaimsIfPossible(from: token)

      guard let expiry = await accessTokenExpiry(for: token) else {
        return token
      }

      let remainingLifetime = expiry.timeIntervalSince(now)
      if remainingLifetime > refreshLeeway {
        return token
      }

      if remainingLifetime > 0 {
        guard await hasUsableRefreshToken(now: now) else {
          return token
        }

        do {
          return try await refreshAccessToken(clearSessionOnFailure: false)
        } catch {
          return token
        }
      }

      if await hasUsableRefreshToken(now: now) {
        return try await refreshAccessToken()
      }

      await clearSession(notify: true)
      throw AuthSessionError.sessionExpired
    }

    if await hasUsableRefreshToken(now: now) {
      return try await refreshAccessToken()
    }

    if !trimmed(await sessionStore.refreshToken).isEmpty {
      await clearSession(notify: true)
      throw AuthSessionError.sessionExpired
    }

    return nil
  }

  func refreshAccessToken() async throws -> String? {
    try await refreshAccessToken(clearSessionOnFailure: true)
  }

  private func refreshAccessToken(clearSessionOnFailure: Bool) async throws -> String? {
    let now = nowProvider()
    guard await hasUsableRefreshToken(now: now) else {
      if clearSessionOnFailure {
        await clearSession(notify: true)
      }
      throw AuthSessionError.notAuthenticated
    }

    if let task = refreshTask {
      return try await task.value
    }

    let refreshID = UUID()
    let task = Task<String?, Error> {
      let refreshToken = self.trimmed(await self.sessionStore.refreshToken)
      guard !refreshToken.isEmpty else {
        if clearSessionOnFailure {
          await self.clearSession(notify: true)
        }
        throw AuthSessionError.notAuthenticated
      }

      let response = try await self.authService.refresh(refreshToken: refreshToken)
      await self.sessionStore.store(authResponse: response)
      await self.syncClaimsIfPossible(from: response.token)
      return self.trimmed(await self.sessionStore.authToken)
    }

    refreshTask = task
    refreshTaskID = refreshID
    
    defer {
      if refreshTaskID == refreshID {
        refreshTask = nil
        refreshTaskID = nil
      }
    }

    do {
      return try await task.value
    } catch {
      if clearSessionOnFailure {
        await clearSession(notify: true)
      }
      throw error
    }
  }

  func logout() async {
    NotificationCenter.default.post(name: .authSessionWillInvalidate, object: nil)
    await authService.logout(refreshToken: await sessionStore.refreshToken)
    await clearSession(notify: true)
  }

  func invalidateSession() async {
    NotificationCenter.default.post(name: .authSessionWillInvalidate, object: nil)
    await clearSession(notify: true)
  }

  private func accessTokenExpiry(for token: String) async -> Date? {
    if let expiry = JWTTokenInspector.expirationDate(in: token) {
      return expiry
    }
    return await sessionStore.authTokenExpiresAt
  }

  private func hasUsableRefreshToken(now: Date) async -> Bool {
    let refreshToken = trimmed(await sessionStore.refreshToken)
    guard !refreshToken.isEmpty else {
      return false
    }

    guard let expiry = await sessionStore.refreshTokenExpiresAt else {
      return true
    }

    return expiry > now
  }

  private func syncClaimsIfPossible(from token: String) async {
    if await sessionStore.currentUserID.isEmpty,
       let userID = JWTTokenInspector.userID(in: token) {
      await sessionStore.setCurrentUserID(userID.uuidString)
    }

    if await sessionStore.authTokenExpiresAt == nil,
       let expiry = JWTTokenInspector.expirationDate(in: token) {
      await sessionStore.setAuthTokenExpiresAt(expiry)
    }
  }

  private func clearSession(notify: Bool) async {
    await sessionStore.clearSession()

    guard notify else {
      return
    }

    NotificationCenter.default.post(name: .authSessionDidInvalidate, object: nil)
  }

  private func trimmed(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
