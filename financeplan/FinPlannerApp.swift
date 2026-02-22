import EntityStore
import Factory
import Sentry
import SwiftUI

@main
struct FinPlannerApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  @InjectedObservable(\Container.appEnvironment) var environmentManager

  var body: some Scene {
    WindowGroup {
      ContentView()
        .id(environmentManager.current)
    }
  }
}
