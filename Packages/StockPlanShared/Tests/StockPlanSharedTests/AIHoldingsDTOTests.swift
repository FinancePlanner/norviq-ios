import Foundation
import StockPlanShared
import Testing

/// The holdings card's wire, as the backend's `assistant/holdings.go` merged it.
@Suite("Assistant holdings DTOs")
struct AIHoldingsDTOTests {
    private let card = """
    {"portfolioListId":"8F1C2B9A-0D4E-4C1B-9E7A-3B5D6C7E8F90","fromCsv":false,"rows":[\
    {"symbol":"AAPL","shares":10,"avgPrice":150.5,"buyDate":"2024-03-15","existing":"none","willReplaceImport":false,"needsCost":false},\
    {"symbol":"MSFT","shares":2.5,"avgPrice":null,"buyDate":null,"existing":"mixed","willReplaceImport":true,"needsCost":true}]}
    """

    @Test("The stored card decodes, nulls included")
    func cardDecodes() throws {
        let proposal = try #require(AIProposedHoldings.decode(arguments: card))
        #expect(proposal.portfolioListId == "8F1C2B9A-0D4E-4C1B-9E7A-3B5D6C7E8F90")
        #expect(proposal.fromCsv == false)
        #expect(proposal.rows.count == 2)
        #expect(proposal.rows[0] == AIProposedHolding(
            symbol: "AAPL", shares: 10, avgPrice: 150.5, buyDate: "2024-03-15",
            existing: "none", willReplaceImport: false, needsCost: false
        ))
        #expect(proposal.rows[1].avgPrice == nil)
        #expect(proposal.rows[1].buyDate == nil)
        #expect(proposal.rows[1].needsCost)
        #expect(proposal.rows[1].willReplaceImport)
    }

    @Test("A card with no rows or unreadable arguments is nil")
    func emptyCardIsNil() {
        #expect(AIProposedHoldings.decode(arguments: #"{"portfolioListId":"x","fromCsv":true,"rows":[]}"#) == nil)
        #expect(AIProposedHoldings.decode(arguments: "not json") == nil)
    }

    @Test("A proposal round-trips")
    func proposalRoundTrips() throws {
        let proposal = try #require(AIProposedHoldings.decode(arguments: card))
        let data = try JSONEncoder().encode(proposal)
        #expect(try JSONDecoder().decode(AIProposedHoldings.self, from: data) == proposal)
    }

    @Test("The confirm body is camel case, leaves nils out, and round-trips")
    func confirmBodyRoundTrips() throws {
        let body = AIReviewedHoldings(
            portfolioListId: "L1",
            replaceExisting: true,
            rows: [
                AIReviewedHolding(symbol: "AAPL", shares: 10, avgPrice: 150.5, buyDate: "2024-03-15"),
                AIReviewedHolding(symbol: "MSFT", shares: 2, avgPrice: 3, buyDate: nil),
            ]
        )
        let data = try JSONEncoder().encode(body)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["portfolioListId"] as? String == "L1")
        #expect(object["replaceExisting"] as? Bool == true)
        let rows = try #require(object["rows"] as? [[String: Any]])
        #expect(rows.count == 2)
        #expect(rows[0]["avgPrice"] as? Double == 150.5)
        #expect(rows[1]["buyDate"] == nil)
        #expect(try JSONDecoder().decode(AIReviewedHoldings.self, from: data) == body)
    }

    @Test("A 422 body reads its collision and its row errors")
    func refusalDecodes() throws {
        let json = #"{"reason":"These holdings already exist: AAPL.","code":"holdings_collision","symbols":["AAPL"],"rows":[{"index":1,"message":"Shares must be above zero."}]}"#
        let refusal = try JSONDecoder().decode(AIHoldingsRefusalResponse.self, from: Data(json.utf8))
        #expect(refusal.code == "holdings_collision")
        #expect(refusal.symbols == ["AAPL"])
        #expect(refusal.rows == [AIHoldingRowError(index: 1, message: "Shares must be above zero.")])
        let plain = try JSONDecoder().decode(AIHoldingsRefusalResponse.self, from: Data(#"{"reason":"Nothing was selected to save."}"#.utf8))
        #expect(plain.code == nil)
        #expect(plain.rows.isEmpty)
    }
}
