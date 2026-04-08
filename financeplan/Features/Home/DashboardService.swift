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

struct DashboardServiceStub: DashboardServicing {
    func getDashboard() async throws -> DashboardResponse {
        DashboardResponse(
            totalValue: 124830.42,
            dailyChange: 2854.12,
            dailyChangePercent: 2.31,
            topPerformers: [],
            bottomPerformers: [],
            sectorAllocation: []
        )
    }

    func getInsights() async throws -> DashboardInsightsResponse {
        DashboardInsightsResponse(
            savingsRate: 15.0,
            budgetStreak: 3,
            watchlistCount: 5,
            cashBuffer: 10000.0,
            financialHealth: DashboardFinancialHealthDTO(
                score: 72,
                maxScore: 100,
                status: .healthy
            )
        )
    }
}
