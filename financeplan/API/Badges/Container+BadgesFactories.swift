import Factory
import Foundation

extension Container {
    var badgesService: Factory<any BadgesServicing> {
        self { @MainActor in
            DefaultBadgesService(
                environmentManager: self.appEnvironment(),
                authSessionManager: self.authSessionManager()
            )
        }
    }
}
