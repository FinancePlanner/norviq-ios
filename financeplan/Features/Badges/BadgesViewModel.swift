import Combine
import Foundation
import StockPlanShared
import Factory

@MainActor
final class BadgesViewModel: ObservableObject {
    @Published var badges: [BadgeProgressResponse] = []
    @Published var totalEarnedTiers: Int = 0
    @Published var totalAvailableTiers: Int = 21
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Injected(\.badgesService) private var service

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await service.getBadges()
            badges = response.badges
            totalEarnedTiers = response.totalEarnedTiers
            totalAvailableTiers = response.totalAvailableTiers
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
