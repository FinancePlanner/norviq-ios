import Factory
import Foundation

extension Container {
  var pilotsService: Factory<any PilotsServicing> {
    self { @MainActor in
      DefaultPilotsService(environmentManager: self.appEnvironment())
    }
  }
}
