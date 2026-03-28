import EntityStore
import Factory
import Sentry
import SwiftUI

@main
struct FinPlannerApp: App {
  @InjectedObservable(\Container.appEnvironment) var environmentManager
  @StateObject private var sessionManager = SessionManager()
  @AppStorage(AppAppearance.storageKey) private var appAppearanceRawValue = AppAppearance.system
    .rawValue

  private var appAppearance: AppAppearance {
    AppAppearance.from(appAppearanceRawValue)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(environmentManager.current)
        .environmentObject(sessionManager)
        .preferredColorScheme(appAppearance.colorScheme)
        .tint(AppTheme.Colors.tint(for: appAppearance.colorScheme ?? .light))
    }
  }
}
