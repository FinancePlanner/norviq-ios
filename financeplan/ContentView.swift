import Factory
import SwiftUI

public struct ContentView: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @Environment(\.colorScheme) private var colorScheme
  @State private var launchCompleted = false
  @State private var launchStarted = false
  @State private var isAuthenticated: Bool
  @State private var requiresInitialStockImport: Bool
  private let splashDelayNanoseconds: UInt64
  private let authSessionManager: AuthSessionManaging
  private let sessionStore: AuthSessionStoring

  public init() {
    let processInfo = ProcessInfo.processInfo
    splashDelayNanoseconds =
      processInfo.arguments.contains("-ui_test_skip_splash") ? 0 : 2_000_000_000

    let store = Container.shared.authSessionStore()

    if processInfo.arguments.contains("-ui_test_reset_session") {
      store.clearSession()
      let defaults = UserDefaults.standard
      defaults.removeObject(forKey: "initial_stock_import_user_ids")
    }

    authSessionManager = Container.shared.authSessionManager()

    if let forcedAuthToken = processInfo.argumentValue(for: "-ui_test_auth_token") {
      store.authToken = forcedAuthToken
      store.authTokenExpiresAt = JWTTokenInspector.expirationDate(in: forcedAuthToken) ?? .distantFuture
    }

    if let forcedRefreshToken = processInfo.argumentValue(for: "-ui_test_refresh_token") {
      store.refreshToken = forcedRefreshToken
      store.refreshTokenExpiresAt = .distantFuture
    }

    if let forcedUserID = processInfo.argumentValue(for: "-ui_test_user_id") {
      store.currentUserID = forcedUserID
    }

    if let forcedUsername = processInfo.argumentValue(for: "-ui_test_username") {
      store.currentUsername = forcedUsername
    }

    if let importedUserID = processInfo.argumentValue(for: "-ui_test_imported_user_id") {
      store.markInitialStockImportCompleted(for: importedUserID)
    }

    sessionStore = store
    _isAuthenticated = State(initialValue: false)
    _requiresInitialStockImport = State(initialValue: false)
  }

  public var body: some View {
    ZStack {
      AppTheme.Colors.topBarBackground(for: colorScheme).ignoresSafeArea()
      WindowSizeSyncView()

      if launchCompleted {
        if isAuthenticated {
          if requiresInitialStockImport {
            OnboardingImportFlow {
              sessionStore.markInitialStockImportCompleted(for: sessionStore.currentUserID)
              requiresInitialStockImport = false
            }
          } else {
            HomeScreen(
              onLogout: {
                await authSessionManager.logout()
              }
            )
          }
        } else {
          LoginScreen(onAuthenticated: {
            applyAuthenticatedState()
          })
        }
      } else {
        SplashScreen()
          .transition(.opacity)
      }
    }
    .environment(\.dynamicTypeSize, .xSmall)
    .containerShape(.rect(cornerRadius: 34, style: .continuous))
    .onAppear {
      syncSessionUsername()
    }
    .onReceive(NotificationCenter.default.publisher(for: .authSessionDidInvalidate)) { _ in
      handleSessionInvalidation()
    }
    .task {
      guard !launchStarted else {
        return
      }

      launchStarted = true
      if splashDelayNanoseconds > 0 {
        try? await Task.sleep(nanoseconds: splashDelayNanoseconds)
      }

      if await authSessionManager.restoreSessionIfNeeded() {
        applyAuthenticatedState()
      } else {
        handleSessionInvalidation()
      }

      withAnimation(.easeInOut(duration: 0.4)) {
        launchCompleted = true
      }
    }
  }

  private func syncSessionUsername() {
    if isAuthenticated {
      sessionManager.updateUsername(sessionStore.currentUsername)
    } else {
      sessionManager.reset()
    }
  }

  private func applyAuthenticatedState() {
    isAuthenticated = true
    let userID = sessionStore.currentUserID
    requiresInitialStockImport =
      userID.isEmpty || !sessionStore.hasCompletedInitialStockImport(for: userID)
    sessionManager.updateUsername(sessionStore.currentUsername)
  }

  private func handleSessionInvalidation() {
    isAuthenticated = false
    requiresInitialStockImport = false
    sessionManager.reset()
  }
}

extension ProcessInfo {
  fileprivate func argumentValue(for name: String) -> String? {
    guard let index = arguments.firstIndex(of: name) else {
      return nil
    }

    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex) else {
      return nil
    }

    return arguments[valueIndex]
  }
}
