import Factory
import Foundation

extension Container {
  var gamificationService: Factory<any GamificationServicing> {
    self { @MainActor in
      DefaultGamificationService(environmentManager: self.appEnvironment())
    }
  }

  /// XP and streaks for the dashboard card, shared so a check-in shows up
  /// wherever the numbers are read.
  var gamificationStore: Factory<GamificationStore> {
    self { @MainActor in GamificationStore() }.singleton
  }
}
