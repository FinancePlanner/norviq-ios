import Factory
import Foundation

extension Container {
  var achievementsService: Factory<any AchievementsServicing> {
    self { @MainActor in
      DefaultAchievementsService(environmentManager: self.appEnvironment())
    }
  }
}
