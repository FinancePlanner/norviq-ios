import Combine
import Foundation
import StockPlanShared
import Factory

@MainActor
final class BadgesViewModel: ObservableObject {
    @Published var badges: [BadgeProgressResponse] = []
    @Published var totalEarnedTiers: Int = 0
    @Published var totalAvailableTiers: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: any BadgesServicing

    init(service: any BadgesServicing = Container.shared.badgesService()) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await service.getBadges()
            badges = response.badges
            totalEarnedTiers = response.totalEarnedTiers
            totalAvailableTiers = response.totalAvailableTiers
            await considerBadgeReview(response.badges)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// A tier earned in the last day is a fresh win. `earnedAt` timestamps mean this
    /// needs no diffing against a previous fetch — the server already tells us when.
    private func considerBadgeReview(_ badges: [BadgeProgressResponse]) async {
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let recent = badges.lazy.compactMap { badge -> (String, String)? in
            let freshest = badge.earnedTiers.compactMap { earned -> Date? in
                formatter.date(from: earned.earnedAt)
                    ?? ISO8601DateFormatter().date(from: earned.earnedAt)
            }.max()
            guard let freshest, freshest >= cutoff else { return nil }
            guard let tier = badge.currentTier else { return nil }
            return (badge.id, tier.rawValue)
        }.first

        guard let (badgeID, tier) = recent else { return }
        let userID = await Container.shared.authSessionStore().currentUserID
        guard !userID.isEmpty else { return }
        Container.shared.reviewPromptCoordinator()
            .consider(.badgeTierEarned(badgeID: badgeID, tier: tier), userID: userID)
    }
}
