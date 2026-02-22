import EntityStore
import Factory
import Sentry
import SwiftUI

struct financeplanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @InjectedObservable(\Container.appEnvironment) var environmentManager

    var body: some Scene {
      WindowGroup {
        ContentView()
          .id(environmentManager.current)
      }
    }
}
