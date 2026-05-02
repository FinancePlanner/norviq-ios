import EntityStore
import Factory
import PostHog
import Sentry
import SwiftUI
import SwiftData
import TelemetryDeck

enum PostHogEnv: String {
  case projectToken = "POSTHOG_PROJECT_TOKEN"
  case host = "POSTHOG_HOST"

  var value: String {
    guard let value = ProcessInfo.processInfo.environment[rawValue] else {
      fatalError("Set \(rawValue) in the Xcode scheme Run environment variables.")
    }
    return value
  }
}

@main
@MainActor
struct NorviqaApp: App {
  @UIApplicationDelegateAdaptor(PushNotificationsAppDelegate.self) var pushNotificationsAppDelegate
  @InjectedObservable(\Container.appEnvironment) var environmentManager
  @StateObject private var sessionManager = SessionManager()
  @Injected(\.analytics) private var analytics
  @AppStorage(AppAppearance.storageKey) private var appAppearanceRawValue = AppAppearance.system
    .rawValue
  @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue

  private var appAppearance: AppAppearance {
    AppAppearance.from(appAppearanceRawValue)
  }

  private var appLanguage: AppLanguage {
    AppLanguage.from(appLanguageRawValue)
  }

  init() {
    TelemetryDeck.initialize(config: .init(appID: "C2B05381-D641-4BE4-B418-5AE02A8DB85F"))
    AppLanguage.applyStoredLanguage()
    let config = PostHogConfig(apiKey: PostHogEnv.projectToken.value, host: PostHogEnv.host.value)
    config.captureApplicationLifecycleEvents = true
    PostHogSDK.shared.setup(config)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(appLanguage.localeIdentifier)
        .id(environmentManager.current)
        .environmentObject(sessionManager)
        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        .preferredColorScheme(appAppearance.colorScheme)
        .tint(AppTheme.Colors.tint(for: appAppearance.colorScheme ?? .light))
        .onAppear {
          AppLanguage.applyStoredLanguage()
          analytics.track("App Launched")
        }
        .onChange(of: appLanguageRawValue) { _, newValue in
          AppLanguage.applyBundleLanguage(AppLanguage.from(newValue))
        }
    }
    .modelContainer(sharedModelContainer)
  }
}
