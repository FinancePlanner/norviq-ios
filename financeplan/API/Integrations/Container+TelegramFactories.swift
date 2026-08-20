import Factory
import Foundation

extension Container {
  var telegramLinkService: Factory<TelegramLinkServiceProtocol> {
    self { @MainActor [unowned self] in
      TelegramLinkService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }
}
