import Foundation
import StockPlanShared
import Factory

protocol BadgesServicing {
    func getBadges() async throws -> BadgesListResponse
}

struct DefaultBadgesService: BadgesServicing {
    let client: BadgesHTTPClient

    init(environmentManager: AppEnvironmentManager, authSessionManager: any AuthSessionManaging) {
        let env = environmentManager.current
        self.client = BadgesHTTPClient(
            baseURL: env.apiBaseUrl,
            session: .shared,
            authTokenProvider: { Container.shared.authSessionStore().authToken }
        )
    }

    func getBadges() async throws -> BadgesListResponse {
        try await client.getBadges()
    }
}

struct BadgesServiceStub: BadgesServicing {
    func getBadges() async throws -> BadgesListResponse {
        let badges: [BadgeProgressResponse] = BadgeType.allCases.map { type in
            let progress = Double.random(in: 0...1)
            let isEarned = progress > 0.7
            return BadgeProgressResponse(
                type: type,
                title: type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                description: "Badge description",
                iconName: "star.fill",
                currentTier: isEarned ? .bronze : nil,
                nextTier: isEarned ? .silver : .bronze,
                progress: progress,
                currentCount: Int(progress * 10),
                targetCount: 10,
                earnedTiers: isEarned ? [EarnedTierInfo(tier: .bronze, earnedAt: ISO8601DateFormatter().string(from: Date()))] : []
            )
        }
        return BadgesListResponse(
            badges: badges,
            totalEarnedTiers: badges.filter { !$0.earnedTiers.isEmpty }.count,
            totalAvailableTiers: 21
        )
    }
}
