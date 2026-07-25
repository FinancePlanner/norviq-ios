import Foundation
import StockPlanShared
import Factory

protocol DashboardServicing: Sendable {
    func getDashboard() async throws -> DashboardResponse
    func getInsights() async throws -> DashboardInsightsResponse
    func getWhyMoved() async throws -> WhyMovedResponse
}

struct DefaultDashboardService: DashboardServicing, @unchecked Sendable {
    let client: DashboardHTTPClient

    init(environmentManager: AppEnvironmentManager, authSessionManager: any AuthSessionManaging) {
        let env = environmentManager.current
        self.client = DashboardHTTPClient(
            baseURL: env.apiBaseUrl,
            session: URLSession.shared,
            authTokenProvider: { await Container.shared.authSessionStore().authToken }
        )
    }

    func getDashboard() async throws -> DashboardResponse {
        try await client.getDashboard()
    }

    func getInsights() async throws -> DashboardInsightsResponse {
        try await client.getInsights()
    }

    func getWhyMoved() async throws -> WhyMovedResponse {
        try await client.getWhyMoved()
    }
}


