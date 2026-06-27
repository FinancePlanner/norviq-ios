import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class BadgesViewModelTests: XCTestCase {
    func testInitialTotalAvailableTiersStartsAtZero() {
        let viewModel = BadgesViewModel(service: MockBadgesService(response: .success(.empty)))

        XCTAssertEqual(viewModel.totalAvailableTiers, 0)
        XCTAssertEqual(viewModel.totalEarnedTiers, 0)
        XCTAssertTrue(viewModel.badges.isEmpty)
    }

    func testLoadUsesBackendBadgeTotalsAndProgress() async {
        let badge = BadgeProgressResponse(
            type: .newsReader,
            title: "News reader",
            description: "Read market news",
            iconName: "newspaper.fill",
            currentTier: .bronze,
            nextTier: .silver,
            progress: 0.5,
            currentCount: 10,
            targetCount: 20,
            earnedTiers: [EarnedTierInfo(tier: .bronze, earnedAt: "2026-06-27T00:00:00Z")]
        )
        let response = BadgesListResponse(
            badges: [badge],
            totalEarnedTiers: 1,
            totalAvailableTiers: 99
        )
        let viewModel = BadgesViewModel(service: MockBadgesService(response: .success(response)))

        await viewModel.load()

        XCTAssertEqual(viewModel.totalAvailableTiers, 99)
        XCTAssertEqual(viewModel.totalEarnedTiers, 1)
        XCTAssertEqual(viewModel.badges, [badge])
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadFailureLeavesServerTotalsUnset() async {
        let viewModel = BadgesViewModel(service: MockBadgesService(response: .failure(MockError.failure)))

        await viewModel.load()

        XCTAssertEqual(viewModel.totalAvailableTiers, 0)
        XCTAssertEqual(viewModel.totalEarnedTiers, 0)
        XCTAssertTrue(viewModel.badges.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
    }
}

private final class MockBadgesService: BadgesServicing, @unchecked Sendable {
    private let response: Result<BadgesListResponse, Error>

    init(response: Result<BadgesListResponse, Error>) {
        self.response = response
    }

    func getBadges() async throws -> BadgesListResponse {
        try response.get()
    }
}

private enum MockError: LocalizedError {
    case failure

    var errorDescription: String? {
        "Failed to load badges"
    }
}

private extension BadgesListResponse {
    static let empty = BadgesListResponse(badges: [], totalEarnedTiers: 0, totalAvailableTiers: 0)
}
