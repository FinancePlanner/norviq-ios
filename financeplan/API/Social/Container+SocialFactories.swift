import Factory
import Foundation

extension Container {
  var socialService: Factory<any SocialServicing> {
    self { @MainActor in
      DefaultSocialService(environmentManager: self.appEnvironment())
    }
  }

  /// One store for the Friends tab, its badge and every sheet that changes the
  /// graph, so a request accepted in one place updates the others.
  var socialStore: Factory<SocialStore> {
    self { @MainActor in SocialStore() }.singleton
  }
}
