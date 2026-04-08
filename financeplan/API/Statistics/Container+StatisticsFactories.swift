import Factory
import Foundation

extension Container {
  var statisticsService: Factory<StatisticsServicing> {
    self { [unowned self] in
      StatisticsHTTPService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }
}
