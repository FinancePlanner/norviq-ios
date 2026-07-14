import Factory
import Combine
import OSLog
import SwiftUI

public struct ContentView: View {
  private static let pushLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
    category: "PushNotificationsUX"
  )

  @Environment(SessionManager.self) private var sessionManager
  @InjectedObservable(\Container.billingManager) private var billingManager
  @InjectedObservable(\Container.appEnvironment) private var environmentManager
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.scenePhase) private var scenePhase
  @State private var launchCompleted = false
  @State private var launchStarted = false
  @State private var isAuthenticated: Bool
  @State private var requiresInitialStockImport: Bool
  @State private var requiresOnboardingQuestionnaire = false
  @State private var isUnlocking = false
  @State private var isAppLocked = false
  @State private var securityCodeInput = ""
  @State private var securityCodeError: String?
  @State private var showSessionRecoveryAlert = false
  @State private var sessionRecoveryMessage = ""
  @State private var startWithSignup = false
  @State private var hasRequestedLoginThisSession = false
  @StateObject private var pushNotificationsCoordinator: PushNotificationsCoordinator
  @AppStorage("useFaceID") private var useFaceID: Bool = true
  private let splashDelay: Duration
  private let authSessionManager: AuthSessionManaging
  private let sessionStore: AuthSessionStoring
  private let appLockManager: AppLockManaging
  private let securityCodeManager: SecurityCodeManaging

  public init() {
    let processInfo = ProcessInfo.processInfo
    splashDelay =
      processInfo.arguments.contains("-ui_test_skip_splash") ? .zero : .seconds(2)

    authSessionManager = Container.shared.authSessionManager()
    appLockManager = Container.shared.appLockManager()
    securityCodeManager = Container.shared.securityCodeManager()
    sessionStore = Container.shared.authSessionStore()

    _pushNotificationsCoordinator = StateObject(
      wrappedValue: Container.shared.pushNotificationsCoordinator()
    )
    _isAuthenticated = State(initialValue: false)
    _requiresInitialStockImport = State(initialValue: false)
  }

  public var body: some View {
    ZStack(alignment: .top) {
      WindowSizeSyncView()

      if launchCompleted {
        if isAuthenticated {
          ZStack {
            AppTheme.Colors.topBarBackground(for: colorScheme).ignoresSafeArea()

            if requiresOnboardingQuestionnaire {
              OnboardingQuestionnairePaywallScreen(
                onCompleted: { _ in
                  Task {
                    let userID = await sessionStore.currentUserID
                    await sessionStore.markOnboardingQuestionnaireCompleted(for: userID)
                    requiresOnboardingQuestionnaire = false
                  }
                }
              )
            } else if requiresInitialStockImport {
              OnboardingImportFlow(
                onFinished: {
                  Task {
                    let userID = await sessionStore.currentUserID
                    await sessionStore.markInitialStockImportCompleted(for: userID)
                    requiresInitialStockImport = false
                  }
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
          Group {
            if !hasRequestedLoginThisSession {
              OnboardingQuestionnaireFlow(
                onLogInRequested: {
                  hasRequestedLoginThisSession = true
                },
                onCompleted: {
                  Task {
                    let userID = await sessionStore.currentUserID
                    await sessionStore.markOnboardingQuestionnaireCompleted(for: userID)
                    applyAuthenticatedState()
                  }
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
        }
      } else {
        SplashScreen()
          .transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    // Honor the user's Dynamic Type setting (Guideline 4 legibility) while bounding
    // the largest accessibility sizes so the data-dense layouts stay intact.
    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    .task {
      await syncSessionUsername()
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
            await billingManager.reconcilePendingBackendSyncIfNeeded()

            await billingManager.refreshBillingContext()
          }
          await enforceAppLockIfNeeded()
        }
      default:
        break
      }
    }
    .onReceive(pushNotificationsCoordinator.$pendingNotificationRoute.compactMap(\.self)) { _ in
      deliverPendingPushNotificationRouteIfPossible()
    }
    .onChange(of: isAuthenticated) { _, _ in
      deliverPendingPushNotificationRouteIfPossible()
    }
    .onChange(of: requiresInitialStockImport) { _, _ in
      deliverPendingPushNotificationRouteIfPossible()
    }
    .onChange(of: requiresOnboardingQuestionnaire) { _, _ in
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

      // UI-test session injection must never ship in release builds.
      #if DEBUG
        let processInfo = ProcessInfo.processInfo
        if processInfo.arguments.contains("-ui_test_reset_session") {
          await sessionStore.clearSession()
          let defaults = UserDefaults.standard
          defaults.removeObject(forKey: "initial_stock_import_user_ids")
        }

        if let forcedAuthToken = processInfo.argumentValue(for: "-ui_test_auth_token") {
          await sessionStore.setAuthToken(forcedAuthToken)
          await sessionStore.setAuthTokenExpiresAt(
            JWTTokenInspector.expirationDate(in: forcedAuthToken) ?? .distantFuture
          )
        }

        if let forcedRefreshToken = processInfo.argumentValue(for: "-ui_test_refresh_token") {
          await sessionStore.setRefreshToken(forcedRefreshToken)
          await sessionStore.setRefreshTokenExpiresAt(.distantFuture)
        }

        if let forcedUserID = processInfo.argumentValue(for: "-ui_test_user_id") {
          await sessionStore.setCurrentUserID(forcedUserID)
        }

        if let forcedUsername = processInfo.argumentValue(for: "-ui_test_username") {
          await sessionStore.setCurrentUsername(forcedUsername)
        }

        if let importedUserID = processInfo.argumentValue(for: "-ui_test_imported_user_id") {
          await sessionStore.markInitialStockImportCompleted(for: importedUserID)
        }
      #endif

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
    .alert("Session Recovery Needed", isPresented: $showSessionRecoveryAlert) {} message: {
      Text(sessionRecoveryMessage)
    }
  }

  private func syncSessionUsername() async {
    if isAuthenticated {
      let username = await sessionStore.currentUsername
      sessionManager.updateUsername(username)
    } else {
      sessionManager.reset()
    }
  }

  private func applyAuthenticatedState() {
    isAuthenticated = true
    Task {
      let userID = await sessionStore.currentUserID
      requiresOnboardingQuestionnaire = await sessionStore.requiresOnboardingQuestionnaire(for: userID)
      let hasImported = await sessionStore.hasCompletedInitialStockImport(for: userID)
      requiresInitialStockImport = userID.isEmpty || !hasImported

      let username = await sessionStore.currentUsername
      sessionManager.updateUsername(username)

      billingManager.configureForCurrentUser()
      await billingManager.reconcilePendingBackendSyncIfNeeded()

      await billingManager.refreshBillingContext()
      pushNotificationsCoordinator.handleAuthenticatedSessionBecameActive()
      await enforceAppLockIfNeeded()
      deliverPendingPushNotificationRouteIfPossible()
    }
  }

  private func handleSessionInvalidation() {
    isAuthenticated = false
    requiresInitialStockImport = false
    requiresOnboardingQuestionnaire = false
    hasRequestedLoginThisSession = false
    isAppLocked = false
    securityCodeInput = ""
    securityCodeError = nil
    appLockManager.clear()
    billingManager.clearCache()
    sessionManager.reset()
    pushNotificationsCoordinator.handleSessionDidInvalidate()
  }

  private func deliverPendingPushNotificationRouteIfPossible() {
    guard
      launchCompleted,
      isAuthenticated,
      !requiresInitialStockImport,
      !requiresOnboardingQuestionnaire
    else {
      return
    }

    guard let route = pushNotificationsCoordinator.consumePendingNotificationRoute() else {
      return
    }

    switch route.kind {
    case .earningsReminder, .targetHit:
      guard let symbol = route.symbol, !symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        Self.pushLogger.warning(
          "push.analytics routed_failure destination=home reason=missing_symbol kind=\(route.kind.rawValue, privacy: .public)"
        )
        return
      }

      Self.pushLogger.info(
        "push.analytics routed_success destination=home kind=\(route.kind.rawValue, privacy: .public) symbol=\(symbol, privacy: .public)"
      )
      NotificationCenter.default.post(
        name: .openStockFromPushNotification,
        object: nil,
        userInfo: [
          "symbol": symbol
        ]
      )
    case .openPortfolio:
      Self.pushLogger.info(
        "push.analytics routed_success destination=home kind=open_portfolio symbol=\(route.symbol ?? "-", privacy: .public)"
      )
      let userInfo: [AnyHashable: Any]? = route.symbol.map { symbol in
        ["symbol": symbol]
      }
      NotificationCenter.default.post(
        name: .openPortfolioFromPushNotification,
        object: nil,
        userInfo: userInfo
      )
    case .taxOpportunity:
      Self.pushLogger.info(
        "push.analytics routed_success destination=tax opportunity=\(route.opportunityID ?? "-", privacy: .public)"
      )
      NotificationCenter.default.post(
        name: .openTaxFromPushNotification,
        object: nil,
        userInfo: route.opportunityID.map { ["opportunityId": $0] }
      )
    case .watchlistScreen:
      Self.pushLogger.info("push.analytics routed_success destination=smart_screen")
      NotificationCenter.default.post(
        name: .openPortfolioFromPushNotification,
        object: nil,
        userInfo: ["automation_destination": "watchlist_screen", "automation_id": route.screenID ?? ""]
      )
    case .rebalancing:
      Self.pushLogger.info("push.analytics routed_success destination=rebalancing")
      NotificationCenter.default.post(
        name: .openPortfolioFromPushNotification,
        object: nil,
        userInfo: ["automation_destination": "rebalancing", "automation_id": route.portfolioListID ?? ""]
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
          .accessibilityHidden(true)
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
        .buttonStyle(.borderedProminent)
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
              .buttonStyle(.bordered)
              .frame(maxWidth: .infinity)
              .disabled(securityCodeInput.count != 6)
          }
        }

        Button("Sign Out", role: .destructive) {
          Task { @MainActor in
            await onSignOut()
          }
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
      }
      .padding(24)
      .frame(maxWidth: 320)
      .appGlassEffect(.rect(cornerRadius: 20))
      .clipShape(.rect(cornerRadius: 20))
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
