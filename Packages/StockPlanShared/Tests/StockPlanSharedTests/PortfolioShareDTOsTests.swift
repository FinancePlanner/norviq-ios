import Foundation
import Testing
@testable import StockPlanShared

@Suite("Portfolio share DTOs")
struct PortfolioShareDTOsTests {
    @Test("Public share JSON carries only percent fields")
    func publicShareHasNoMoneyKeys() throws {
        let dto = PublicPortfolioShareResponse(
            asOf: "2026-09-24",
            totals: PortfolioShareTotals(unrealizedPnlPercent: 12.5, dayChangePercent: -0.4, ytdPercent: 8.1),
            holdings: [PortfolioShareHolding(
                symbol: "AAPL",
                weightPercent: 40,
                unrealizedPnlPercent: 20,
                dayChangePercent: 1
            )],
            otherWeightPercent: nil
        )
        let data = try JSONEncoder().encode(dto)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(json.keys) == ["asOf", "totals", "holdings"])
        let holding = try #require((json["holdings"] as? [[String: Any]])?.first)
        #expect(Set(holding.keys) == ["symbol", "weightPercent", "unrealizedPnlPercent", "dayChangePercent"])
        let decoded = try JSONDecoder().decode(PublicPortfolioShareResponse.self, from: data)
        #expect(decoded == dto)
    }

    @Test("Link status round-trips with and without a link")
    func linkStatusRoundTrip() throws {
        let link = PortfolioShareLinkResponse(
            slug: "pabc",
            url: "https://norviq.org/p/pabc",
            scope: "all",
            createdAt: "2026-09-24T10:00:00Z"
        )
        for status in [PortfolioShareLinkStatusResponse(link: link), PortfolioShareLinkStatusResponse(link: nil)] {
            let data = try JSONEncoder().encode(status)
            #expect(try JSONDecoder().decode(PortfolioShareLinkStatusResponse.self, from: data) == status)
        }
    }
}
