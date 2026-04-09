import Factory
import Foundation

extension Container {
    var dashboardService: Factory<any DashboardServicing> {
        self { @MainActor in
            DefaultDashboardService(
                environmentManager: self.appEnvironment(),
                authSessionManager: self.authSessionManager()
            )
        }
    }
}
