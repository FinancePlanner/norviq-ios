import Factory
import Foundation

extension Container {
    var badgesService: Factory<any BadgesServicing> {
        self {
            DefaultBadgesService(
                environmentManager: self.appEnvironment(),
                authSessionManager: self.authSessionManager()
            )
        }
    }
}
