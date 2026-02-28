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
  private let authService: AuthServicing
  private let sessionStore: AuthSessionStoring

  public init() {
    let processInfo = ProcessInfo.processInfo
    splashDelayNanoseconds =
      processInfo.arguments.contains("-ui_test_skip_splash") ? 0 : 2_000_000_000

    if processInfo.arguments.contains("-ui_test_reset_session") {
      let defaults = UserDefaults.standard
      defaults.removeObject(forKey: "auth_token")
      defaults.removeObject(forKey: "refresh_token")
      defaults.removeObject(forKey: "current_user_id")
      defaults.removeObject(forKey: "current_username")
      defaults.removeObject(forKey: "initial_stock_import_user_ids")
      defaults.synchronize()
    }

    authService = Container.shared.authService()
    let store = Container.shared.authSessionStore()

    if let forcedAuthToken = processInfo.argumentValue(for: "-ui_test_auth_token") {
      store.authToken = forcedAuthToken
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
    let hasSession = !store.authToken.isEmpty
    _isAuthenticated = State(initialValue: hasSession)
    _requiresInitialStockImport = State(
      initialValue: hasSession
        && (store.currentUserID.isEmpty
          || !store.hasCompletedInitialStockImport(for: store.currentUserID))
    )
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
                await authService.logout(refreshToken: sessionStore.refreshToken)
                sessionStore.authToken = ""
                sessionStore.refreshToken = ""
                sessionStore.currentUsername = ""
                isAuthenticated = false
                requiresInitialStockImport = false
                sessionManager.reset()
              }
            )
          }
        } else {
          LoginScreen(onAuthenticated: {
            isAuthenticated = true
            let userID = sessionStore.currentUserID
            requiresInitialStockImport =
              userID.isEmpty || !sessionStore.hasCompletedInitialStockImport(for: userID)
            sessionManager.updateUsername(sessionStore.currentUsername)
          })
        }
      } else {
        SplashScreen()
          .transition(.opacity)
      }
    }
    .onAppear {
      syncSessionUsername()
    }
    .task {
      guard !launchStarted else {
        return
      }

      launchStarted = true
      if splashDelayNanoseconds > 0 {
        try? await Task.sleep(nanoseconds: splashDelayNanoseconds)
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
