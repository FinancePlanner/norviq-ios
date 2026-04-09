import Combine
import Factory
import SwiftUI

final class WindowSize: ObservableObject {
  @Published var size: CGSize = .zero
  @Published var horizontalSizeClass: UserInterfaceSizeClass?

  var effectiveFormMaxWidth: CGFloat {
    if horizontalSizeClass == .regular {
      return 520
    }
    let fallbackWidth: CGFloat = 380
    let currentWidth = size.width > 0 ? size.width : fallbackWidth
    return min(max(currentWidth - 24, 280), 460)
  }

  func updateSizeClass(_ sizeClass: UserInterfaceSizeClass?) {
    horizontalSizeClass = sizeClass
  }
}

extension Container {
  var appEnvironment: Factory<AppEnvironmentManager> {
    self { AppEnvironmentManager() }.singleton
  }

  var windowSize: Factory<WindowSize> {
    self { WindowSize() }.singleton
  }

  var authService: Factory<AuthServicing> {
    self { AuthService(environmentManager: self.appEnvironment()) }.singleton
  }

  var authSessionStore: Factory<AuthSessionStoring> {
    self { UserDefaultsAuthSessionStore() }.singleton
  }

  var authSessionManager: Factory<AuthSessionManaging> {
    self {
      AuthSessionManager(
        authService: self.authService(),
        sessionStore: self.authSessionStore()
      )
    }.singleton
  }

  var stockService: Factory<StockService> {
    self {
      StockService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }.singleton
  }

  var feedbackService: Factory<FeedbackService> {
    self {
      FeedbackService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }.singleton
  }

  func reloadEnvironmentConfiguration(for _: AppEnvironment, onUpdate: @escaping () -> Void) {
    manager.reset(scope: .singleton)
    onUpdate()
  }
}
