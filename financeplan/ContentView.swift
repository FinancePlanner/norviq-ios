import Factory
import Combine
import OSLog
import SwiftUI

public struct ContentView: View {
  private static let pushLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
    category: "PushNotificationsUX"
  )

  @EnvironmentObject private var sessionManager: SessionManager
  @InjectedObservable(\Container.billingManager) private var billingManager
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.scenePhase) private var scenePhase
  @State private var launchCompleted = false
  @State private var launchStarted = false
  @State private var isAuthenticated: Bool
  @State private var requiresInitialStockImport: Bool
  @State private var isUnlocking = false
  @State private var isAppLocked = false
  @State private var securityCodeInput = ""
  @State private var securityCodeError: String?
  @State private var showSessionRecoveryAlert = false
  @State private var sessionRecoveryMessage = ""
  @State private var startWithSignup = false
  @StateObject private var pushNotificationsCoordinator: PushNotificationsCoordinator
  @AppStorage("useFaceID") private var useFaceID: Bool = true
  @AppStorage("hasSeenPrivacyScreen") private var hasSeenPrivacyScreen: Bool = false
  @AppStorage("hasSeenPreLoginPaywall") private var hasSeenPreLoginPaywall: Bool = false
  private let splashDelay: Duration
  private let authSessionManager: AuthSessionManaging
  private let sessionStore: AuthSessionStoring
  private let appLockManager: AppLockManaging
  private let securityCodeManager: SecurityCodeManaging

  public init() {
    let processInfo = ProcessInfo.processInfo
    splashDelay =
      processInfo.arguments.contains("-ui_test_skip_splash") ? .zero : .seconds(2)

    let store = Container.shared.authSessionStore()

    if processInfo.arguments.contains("-ui_test_reset_session") {
      store.clearSession()
      let defaults = UserDefaults.standard
      defaults.removeObject(forKey: "initial_stock_import_user_ids")
    }

    authSessionManager = Container.shared.authSessionManager()
    appLockManager = Container.shared.appLockManager()
    securityCodeManager = Container.shared.securityCodeManager()

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
    _pushNotificationsCoordinator = StateObject(
      wrappedValue: Container.shared.pushNotificationsCoordinator()
    )
    _isAuthenticated = State(initialValue: false)
    _requiresInitialStockImport = State(initialValue: false)
  }

  public var body: some View {
    ZStack(alignment: .top) {
      AppTheme.Colors.topBarBackground(for: colorScheme).ignoresSafeArea()
      WindowSizeSyncView()

      if launchCompleted {
        if isAuthenticated {
          ZStack {
            if requiresInitialStockImport {
              OnboardingImportFlow(
                onFinished: {
                  sessionStore.markInitialStockImportCompleted(for: sessionStore.currentUserID)
                  requiresInitialStockImport = false
                },
                onSignOut: {
                  await authSessionManager.logout()
                }
              )
            } else {
              HomeScreen(
                onLogout: {
                  await authSessionManager.logout()
                }
              )
            }

            if isAppLocked {
              AppLockOverlay(
                isUnlocking: isUnlocking,
                securityCodeInput: $securityCodeInput,
                securityCodeError: securityCodeError,
                isSecurityCodeEnabled: securityCodeManager.isEnabled,
                onUnlock: {
                  guard !isUnlocking else { return }
                  isUnlocking = true
                  Task { @MainActor in
                    let unlocked = await appLockManager.unlock()
                    isAppLocked = !unlocked
                    if !unlocked {
                      sessionRecoveryMessage = "Authentication failed. Please try again or sign in again."
                    }
                    isUnlocking = false
                  }
                },
                onSecurityCodeUnlock: {
                  verifySecurityCodeUnlock()
                },
                onSignOut: {
                  await authSessionManager.logout()
                }
              )
            }
          }
        } else {
          if !hasSeenPreLoginPaywall {
            PreLoginPaywallScreen(
              onContinue: {
                hasSeenPreLoginPaywall = true
              }
            )
          } else if !hasSeenPrivacyScreen {
            PrivacyWelcomeScreen(
              onSignIn: {
                hasSeenPrivacyScreen = true
              },
              onSignUp: {
                startWithSignup = true
                hasSeenPrivacyScreen = true
              }
            )
          } else {
            LoginScreen(
              onAuthenticated: {
                applyAuthenticatedState()
              },
              startWithSignup: startWithSignup
            )
          }
        }
      } else {
        SplashScreen()
          .transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//    .environment(\.dynamicTypeSize, .xSmall)
    .onAppear {
      syncSessionUsername()
    }
    .onReceive(NotificationCenter.default.publisher(for: .authSessionDidInvalidate)) { _ in
      handleSessionInvalidation()
    }
    .onReceive(NotificationCenter.default.publisher(for: .authSessionWillInvalidate)) { _ in
      pushNotificationsCoordinator.handleSessionWillInvalidate()
    }
    .onReceive(NotificationCenter.default.publisher(for: .authSessionStorageFailure)) { _ in
      sessionRecoveryMessage = "Secure session storage is unavailable on this device. Please sign in again."
      showSessionRecoveryAlert = true
      Task {
        await authSessionManager.invalidateSession()
      }
      handleSessionInvalidation()
    }
    .onChange(of: scenePhase) { _, newPhase in
      switch newPhase {
      case .background:
        appLockManager.appDidEnterBackground()
      case .active:
        Task {
          await pushNotificationsCoordinator.refreshAuthorizationStatus()
          if isAuthenticated {
            billingManager.configureForCurrentUser()
            await billingManager.refreshBillingContext()
          }
          await enforceAppLockIfNeeded()
        }
      default:
        break
      }
    }
    .onReceive(pushNotificationsCoordinator.$pendingNotificationRoute.compactMap { $0 }) { _ in
      deliverPendingPushNotificationRouteIfPossible()
    }
    .onChange(of: isAuthenticated) { _, _ in
      deliverPendingPushNotificationRouteIfPossible()
    }
    .onChange(of: requiresInitialStockImport) { _, _ in
      deliverPendingPushNotificationRouteIfPossible()
    }
    .onChange(of: launchCompleted) { _, _ in
      deliverPendingPushNotificationRouteIfPossible()
    }
    .task {
      guard !launchStarted else {
        return
      }

      launchStarted = true
      if splashDelay != .zero {
        try? await Task.sleep(for: splashDelay)
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
    .sheet(isPresented: $pushNotificationsCoordinator.showPostLoginExplainer) {
      PushNotificationsExplainerSheet(
        onEnable: {
          await pushNotificationsCoordinator.enableFromExplainer()
        },
        onNotNow: {
          pushNotificationsCoordinator.dismissExplainer()
        }
      )
    }
    .alert("Session Recovery Needed", isPresented: $showSessionRecoveryAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(sessionRecoveryMessage)
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
    Task {
      billingManager.configureForCurrentUser()
      await billingManager.refreshBillingContext()
      pushNotificationsCoordinator.handleAuthenticatedSessionBecameActive()
      await enforceAppLockIfNeeded()
      deliverPendingPushNotificationRouteIfPossible()
    }
  }

  private func handleSessionInvalidation() {
    isAuthenticated = false
    requiresInitialStockImport = false
    isAppLocked = false
    securityCodeInput = ""
    securityCodeError = nil
    appLockManager.clear()
    billingManager.clearCache()
    sessionManager.reset()
    pushNotificationsCoordinator.handleSessionDidInvalidate()
  }

  private func deliverPendingPushNotificationRouteIfPossible() {
    guard launchCompleted, isAuthenticated, !requiresInitialStockImport else {
      return
    }

    guard let route = pushNotificationsCoordinator.consumePendingNotificationRoute() else {
      return
    }

    switch route.kind {
    case .targetHit:
      guard let symbol = route.symbol, !symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        Self.pushLogger.warning("push.analytics routed_failure destination=home reason=missing_symbol kind=target_hit")
        return
      }

      Self.pushLogger.info("push.analytics routed_success destination=home kind=target_hit symbol=\(symbol, privacy: .public)")
      NotificationCenter.default.post(
        name: .openStockFromPushNotification,
        object: nil,
        userInfo: [
          "symbol": symbol
        ]
      )
    case .openPortfolio:
      Self.pushLogger.info("push.analytics routed_success destination=home kind=open_portfolio symbol=\(route.symbol ?? "-", privacy: .public)")
      let userInfo: [AnyHashable: Any]? = route.symbol.map { symbol in
        ["symbol": symbol]
      }
      NotificationCenter.default.post(
        name: .openPortfolioFromPushNotification,
        object: nil,
        userInfo: userInfo
      )
    }
  }

  private func enforceAppLockIfNeeded() async {
    let result = await appLockManager.enforceIfNeeded(
      isAuthenticated: isAuthenticated,
      isEnabled: useFaceID
    )
    isAppLocked = (result == .locked)

    if result == .requiresReauthentication {
      sessionRecoveryMessage = "Unable to validate device authentication. Please sign in again."
      showSessionRecoveryAlert = true
      await authSessionManager.invalidateSession()
      handleSessionInvalidation()
    }
  }

  private func verifySecurityCodeUnlock() {
    do {
      if try securityCodeManager.verifyCode(securityCodeInput) {
        securityCodeInput = ""
        securityCodeError = nil
        isAppLocked = false
        appLockManager.clear()
      } else {
        securityCodeError = "That security code is incorrect."
      }
    } catch {
      securityCodeError = (error as? LocalizedError)?.errorDescription ?? "Unable to verify Security Code."
    }
  }
}

private struct AppLockOverlay: View {
  let isUnlocking: Bool
  @Binding var securityCodeInput: String
  let securityCodeError: String?
  let isSecurityCodeEnabled: Bool
  let onUnlock: () -> Void
  let onSecurityCodeUnlock: () -> Void
  let onSignOut: () async -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.35).ignoresSafeArea()

      VStack(spacing: 16) {
        Image(systemName: "lock.shield.fill")
          .font(.system(size: 40))
          .foregroundStyle(.primary)

        Text("Unlock to continue")
          .font(.headline)

        Button(action: onUnlock) {
          HStack(spacing: 8) {
            if isUnlocking {
              ProgressView()
            }
            Text("Unlock")
              .fontWeight(.semibold)
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .disabled(isUnlocking)

        if isSecurityCodeEnabled {
          VStack(alignment: .leading, spacing: 8) {
            SecureField("Security Code", text: $securityCodeInput)
              .keyboardType(.numberPad)
              .textContentType(.oneTimeCode)
              .multilineTextAlignment(.center)
              .font(.title3.monospacedDigit())
              .padding(.horizontal, 12)
              .padding(.vertical, 10)
              .appGlassEffect(.rect(cornerRadius: 8), interactive: true)
              .onChange(of: securityCodeInput) { _, newValue in
                securityCodeInput = String(newValue.filter(\.isNumber).prefix(6))
              }

            if let securityCodeError {
              Text(securityCodeError)
                .typography(.caption)
                .foregroundStyle(AppTheme.Colors.danger)
            }

            Button("Unlock with Security Code", action: onSecurityCodeUnlock)
              .buttonStyle(.glass)
              .frame(maxWidth: .infinity)
              .disabled(securityCodeInput.count != 6)
          }
        }

        Button(role: .destructive) {
          Task { @MainActor in
            await onSignOut()
          }
        } label: {
          Text("Sign Out")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
      }
      .padding(24)
      .frame(maxWidth: 320)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .appGlassEffect(.rect(cornerRadius: 20))
      .padding(.horizontal, 24)
    }
    .transition(.opacity)
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
