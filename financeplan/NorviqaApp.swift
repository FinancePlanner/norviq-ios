import EntityStore
import Factory
import PostHog
import Sentry
import SwiftUI
import SwiftData
import TelemetryDeck

enum PostHogEnv: String {
  case projectToken = "PostHogProjectToken"
  case host = "PostHogHost"

  var value: String {
    Bundle.main.object(forInfoDictionaryKey: rawValue) as? String ?? ""
  }
}

@main
@MainActor
struct NorviqApp: App {
  @UIApplicationDelegateAdaptor(PushNotificationsAppDelegate.self) var pushNotificationsAppDelegate
  @InjectedObservable(\Container.appEnvironment) var environmentManager
  @State private var sessionManager = SessionManager()
  @Injected(\.analytics) private var analytics
  @AppStorage(AppAppearance.storageKey) private var appAppearanceRawValue = AppAppearance.system
    .rawValue
  @AppStorage(BrandTheme.storageKey) private var brandThemeRawValue = BrandTheme.vigil.rawValue
  @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue

  private var appAppearance: AppAppearance {
    AppAppearance.from(appAppearanceRawValue)
  }

  private var appLanguage: AppLanguage {
    AppLanguage.from(appLanguageRawValue)
  }

  /// The colour scheme actually in effect.
  ///
  /// `appAppearance.colorScheme` is nil for `.system`, which is the default, so
  /// `?? .light` / `?? .dark` fallbacks silently pick the wrong scheme for most
  /// users. Fall back to the live system trait instead.
  private var resolvedColorScheme: ColorScheme {
    if let scheme = appAppearance.colorScheme {
      return scheme
    }
    return UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
  }

  init() {
    #if DEBUG
    Self.applyUITestAppearanceOverride()
    #endif

    TelemetryDeck.initialize(config: .init(appID: "C2B05381-D641-4BE4-B418-5AE02A8DB85F"))
    
    // Initialize Sentry
    if let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String, !dsn.isEmpty {
      #if DEBUG
      let defaultEnvironment = "development"
      #else
      let defaultEnvironment = "production"
      #endif
      let environment = Bundle.main.object(forInfoDictionaryKey: "SENTRY_ENVIRONMENT") as? String
        ?? defaultEnvironment
      SentrySDK.start { options in
        options.dsn = dsn
        options.environment = environment
        options.tracesSampleRate = 0.2
        options.enableAppHangTracking = true
        options.enableCaptureFailedRequests = true
        options.beforeSend = { event in
          event.tags?["platform"] = "cocoa"
          return event
        }
      }
    }

    AppLanguage.applyStoredLanguage()
    let token = PostHogEnv.projectToken.value
    let host = PostHogEnv.host.value
    if !token.isEmpty, !host.isEmpty {
      let config = PostHogConfig(projectToken: token, host: host)
      config.captureApplicationLifecycleEvents = true
      PostHogSDK.shared.setup(config)
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(appLanguage.localeIdentifier)
        .id(environmentManager.current)
        .id(brandThemeRawValue)
        .environment(sessionManager)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .preferredColorScheme(appAppearance.colorScheme)
        // Tint resolves from the environment rather than from the stored
        // setting, so it tracks the real scheme when appearance is .system and
        // updates when the device flips light/dark.
        .modifier(AppTintModifier())
        .onAppear {
          AppLanguage.applyStoredLanguage()
          analytics.track("App Launched")
          VigilNavigationAppearance.apply(colorScheme: resolvedColorScheme)
        }
        .onChange(of: brandThemeRawValue) { _, _ in
          VigilNavigationAppearance.apply(colorScheme: resolvedColorScheme)
        }
        .onChange(of: appAppearanceRawValue) { _, _ in
          VigilNavigationAppearance.apply(colorScheme: resolvedColorScheme)
        }
        .onChange(of: appLanguageRawValue) { _, newValue in
          AppLanguage.applyBundleLanguage(AppLanguage.from(newValue))
        }
    }
    .modelContainer(sharedModelContainer)
  }

  #if DEBUG
  private static func applyUITestAppearanceOverride() {
    guard let rawValue = ProcessInfo.processInfo.norviqArgumentValue(for: "-ui_test_app_appearance"),
          let appearance = AppAppearance(rawValue: rawValue) else {
      return
    }

    UserDefaults.standard.set(appearance.rawValue, forKey: AppAppearance.storageKey)
  }
  #endif
}

/// Applies the brand tint using the *resolved* colour scheme.
///
/// Reading `\.colorScheme` from the environment inside the window hierarchy is
/// what makes this correct: `preferredColorScheme` and the device setting both
/// land there, whereas the stored `AppAppearance` is nil for `.system`.
private struct AppTintModifier: ViewModifier {
  @Environment(\.colorScheme) private var scheme

  func body(content: Content) -> some View {
    content.tint(AppTheme.Colors.tint(for: scheme))
  }
}

#if DEBUG
private extension ProcessInfo {
  func norviqArgumentValue(for name: String) -> String? {
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
#endif
