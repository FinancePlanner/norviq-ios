import Factory
import Foundation

extension Container {
    var goalsService: Factory<any GoalsServicing> {
        self { @MainActor in
            DefaultGoalsService(
                environmentManager: self.appEnvironment(),
                authSessionManager: self.authSessionManager()
            )
        }
    }
}
