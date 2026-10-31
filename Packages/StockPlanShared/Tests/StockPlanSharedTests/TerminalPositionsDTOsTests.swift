import Foundation
import Testing
@testable import StockPlanShared

struct TerminalPositionsDTOsTests {
    @Test
    func `position response round-trips with camelCase keys and nil derived fields`() throws {
        let response = TerminalPositionResponse(
            id: "6F9619FF-8B86-D011-B42D-00C04FC964FF", ticker: "VG", sharesOutstanding: 2_600_000_000,
            terminalShareCount: 0, terminalMarketCap: 12_500_000_000, valueWanted: 500_000, sharesOwned: 0,
            currentSharePrice: nil, notes: nil, sortOrder: 2,
            terminalSharePrice: nil, sharesNeeded: nil, capitalAtTodayPrice: nil, progress: nil,
            sharesStillNeeded: nil, gapValueAtTerminal: nil, scenarioError: "share_count_not_positive",
            createdAt: "2026-10-09T08:00:00Z", updatedAt: "2026-10-09T08:00:00Z"
        )
        let data = try JSONEncoder().encode(response)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"terminalShareCount\""))
        #expect(json.contains("\"scenarioError\":\"share_count_not_positive\""))
        #expect(try JSONDecoder().decode(TerminalPositionResponse.self, from: data) == response)
    }

    @Test
    func `update request carries only the fields being changed plus clear`() throws {
        let update = TerminalPositionUpdateRequest(valueWanted: 750_000, clear: ["currentSharePrice"])
        let json = try #require(String(data: JSONEncoder().encode(update), encoding: .utf8))
        #expect(json.contains("\"valueWanted\":750000"))
        #expect(json.contains("\"clear\":[\"currentSharePrice\"]"))
        #expect(!json.contains("\"ticker\""))
    }

    @Test
    func `autobuy response decodes an unknown cadence without failing`() throws {
        let json = #"{"id":"a","ticker":null,"label":"401k","amount":5000,"cadence":"quarterly","percent":0.04,"active":true,"monthlyEquivalent":null,"createdAt":"x","updatedAt":"x"}"#
        let decoded = try JSONDecoder().decode(AutobuyResponse.self, from: Data(json.utf8))
        #expect(decoded.cadence == .unknown)
    }

    @Test
    func `summary and suggestions round-trip`() throws {
        let summary = TerminalPositionsSummaryResponse(
            currency: "EUR", positionCount: 2, totalValueWanted: 1_500_000, totalGapValueAtTerminal: 318_181.8,
            totalCapitalAtTodayPrice: nil, pricedPositionCount: 0, monthlyAutobuyTotal: 354.17, topPositions: []
        )
        #expect(try JSONDecoder()
            .decode(TerminalPositionsSummaryResponse.self, from: JSONEncoder().encode(summary)) == summary)
        let facts = ShareFactsSuggestion(
            ticker: "AMZN", sharesOutstanding: 10_600_000_000, currentSharePrice: 221.3,
            currency: "USD", asOf: "2026-09-30", sources: ["https://www.sec.gov/x"]
        )
        #expect(try JSONDecoder().decode(ShareFactsSuggestion.self, from: JSONEncoder().encode(facts)) == facts)
    }
}
