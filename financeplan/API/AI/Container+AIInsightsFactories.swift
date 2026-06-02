import Factory
import Foundation

extension Container {
  var aiInsightsService: Factory<AIInsightsServicing> {
    self { @MainActor [unowned self] in
      AIInsightsHTTPService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }
}
