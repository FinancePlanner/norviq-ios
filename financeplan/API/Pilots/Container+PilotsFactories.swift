import Factory
import Foundation

extension Container {
  var pilotsService: Factory<any PilotsServicing> {
    self { @MainActor in
      DefaultPilotsService(environmentManager: self.appEnvironment())
    }
  }

  /// Shared so the workspace row, the portfolio banner and the pilot screens
  /// see the same follows.
  var pilotsStore: Factory<PilotsStore> {
    self { @MainActor in PilotsStore() }.singleton
  }
}
