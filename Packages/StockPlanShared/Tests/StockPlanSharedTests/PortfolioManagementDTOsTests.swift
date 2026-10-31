import Foundation
import Testing
@testable import StockPlanShared

struct PortfolioManagementDTOsTests {
    @Test
    func `portfolio contract round trips every domain dimension`() throws {
        let capabilities = PortfolioCapabilities(
            canView: true,
            canEdit: true,
            canManageMembers: true,
            canManageConnections: true,
            canArchive: true,
            canDelete: true
        )
        let portfolio = Portfolio(
            id: "portfolio-1",
            ownerUserId: "user-1",
            name: "Retirement sandbox",
            purpose: .retirement,
            ownership: .joint,
            mode: .hypothetical,
            baseCurrency: "EUR",
            isDefault: false,
            sourcePortfolioId: "portfolio-source",
            clonedAt: "2026-07-14T08:00:00Z",
            currentUserRole: .owner,
            capabilities: capabilities,
            createdAt: "2026-07-14T08:00:00Z"
        )

        let data = try JSONEncoder().encode(portfolio)
        let decoded = try JSONDecoder().decode(Portfolio.self, from: data)

        #expect(decoded == portfolio)
        #expect(decoded.purpose == .retirement)
        #expect(decoded.ownership == .joint)
        #expect(decoded.mode == .hypothetical)
    }

    @Test
    func `portfolio creation contract preserves clone options`() throws {
        let request = PortfolioCreateRequest(
            name: "Alternative allocation",
            purpose: .personal,
            ownership: .individual,
            mode: .hypothetical,
            baseCurrency: "USD",
            sourcePortfolioId: "portfolio-1",
            copyRetirementPlan: true
        )

        let data = try JSONEncoder().encode(request)
        #expect(try JSONDecoder().decode(PortfolioCreateRequest.self, from: data) == request)
    }

    @Test
    func `membership invitation and cash contracts round trip`() throws {
        let membership = PortfolioMembership(
            id: "membership-1",
            portfolioId: "portfolio-1",
            userId: "user-2",
            displayName: "Alex",
            email: "alex@example.com",
            role: .editor,
            status: .active,
            joinedAt: "2026-07-14T09:00:00Z",
            createdAt: "2026-07-14T08:30:00Z"
        )
        let invitation = PortfolioInvitation(
            id: "invitation-1",
            portfolioId: "portfolio-1",
            email: "alex@example.com",
            status: .pending,
            expiresAt: "2026-07-21T08:30:00Z",
            createdAt: "2026-07-14T08:30:00Z"
        )
        let cash = PortfolioCashPosition(
            id: "cash-1",
            portfolioId: "portfolio-1",
            label: "Emergency reserve",
            currency: "EUR",
            balance: 12500,
            asOf: "2026-07-14",
            createdAt: "2026-07-14T08:00:00Z"
        )

        #expect(try roundTrip(membership) == membership)
        #expect(try roundTrip(invitation) == invitation)
        #expect(try roundTrip(cash) == cash)
    }

    @Test
    func `comparison contract carries both portfolio columns and holding deltas`() throws {
        let left = PortfolioComparisonColumn(
            portfolioId: "left",
            name: "Current",
            baseCurrency: "EUR",
            totalValue: 100_000,
            cashBalance: 10000,
            holdingCount: 4
        )
        let right = PortfolioComparisonColumn(
            portfolioId: "right",
            name: "What if",
            baseCurrency: "EUR",
            totalValue: 105_000,
            cashBalance: 5000,
            holdingCount: 5
        )
        let comparison = PortfolioComparison(
            left: left,
            right: right,
            holdings: [
                .init(
                    symbol: "VWCE",
                    leftValue: 50000,
                    rightValue: 60000,
                    leftWeightPercent: 50,
                    rightWeightPercent: 57.14,
                    valueDifference: 10000,
                    weightDifferencePercent: 7.14
                ),
            ],
            generatedAt: "2026-07-14T10:00:00Z"
        )

        #expect(try roundTrip(comparison) == comparison)
    }

    private func roundTrip<Value: Codable>(_ value: Value) throws -> Value {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(Value.self, from: data)
    }
}
