import Foundation
import StockPlanShared
import Factory

protocol DashboardServicing {
    func getDashboard() async throws -> DashboardResponse
    func getInsights() async throws -> DashboardInsightsResponse
}

struct DefaultDashboardService: DashboardServicing {
    let client: DashboardHTTPClient

    init(environmentManager: AppEnvironmentManager, authSessionManager: any AuthSessionManaging) {
        let env = environmentManager.current
        self.client = DashboardHTTPClient(
            baseURL: env.apiBaseUrl,
            session: .shared,
            authTokenProvider: { Container.shared.authSessionStore().authToken }
        )
    }

    func getDashboard() async throws -> DashboardResponse {
        try await client.getDashboard()
    }

    func getInsights() async throws -> DashboardInsightsResponse {
        try await client.getInsights()
    }
}


