import Foundation
import StockPlanShared
import Factory

protocol BadgesServicing: Sendable {
    func getBadges() async throws -> BadgesListResponse
}

struct DefaultBadgesService: BadgesServicing {
    let client: BadgesHTTPClient

    init(environmentManager: AppEnvironmentManager, authSessionManager: any AuthSessionManaging) {
        let env = environmentManager.current
        self.client = BadgesHTTPClient(
            baseURL: env.apiBaseUrl,
            session: URLSession.shared,
            authTokenProvider: { Container.shared.authSessionStore().authToken }
        )
    }

    func getBadges() async throws -> BadgesListResponse {
        try await client.getBadges()
    }
}


