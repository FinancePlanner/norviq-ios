import Foundation
import Testing
@testable import StockPlanShared

struct TaxOptimizationV2DTOTests {
    @Test
    func `tax v1 dashboard remains decodable`() throws {
        let json = #"""
        {
          "generatedAt":"2026-07-18T00:00:00Z",
          "taxYear":2026,
          "jurisdiction":"US",
          "ruleVersion":"US-2026.1",
          "isStale":false,
          "profileComplete":true,
          "summary":{
            "realizedEstimatedLiability":{"amount":0,"currency":"USD"},
            "embeddedUnrealizedLiability":{"amount":0,"currency":"USD"},
            "harvestableLosses":{"amount":0,"currency":"USD"},
            "estimatedNetBenefit":{"amount":0,"currency":"USD"},
            "shortTermCarryover":{"amount":0,"currency":"USD"},
            "longTermCarryover":{"amount":0,"currency":"USD"}
          },
          "opportunities":[],
          "unsupportedValue":{"amount":0,"currency":"USD"},
          "assumptions":[],
          "disclaimer":"Educational estimate only."
        }
        """#

        let response = try JSONDecoder().decode(TaxDashboardResponse.self, from: Data(json.utf8))

        #expect(response.catalogVersion == nil)
        #expect(response.taxDrag == nil)
        #expect(response.locationOpportunities == nil)
    }

    @Test
    func `tax v2 action plan round trips exact lots and rebalancing link`() throws {
        let money = TaxMoney(amount: 4800, currency: "USD")
        let leg = TaxActionLeg(
            id: "sell-1",
            accountId: "account-1",
            portfolioId: "portfolio-1",
            instrumentId: "instrument-1",
            symbol: "XYZ",
            side: .sell,
            quantity: 12,
            notional: money,
            lotIds: ["lot-1"],
            status: .planned
        )
        let response = TaxActionPlanResponse(
            id: "plan-1",
            scenarioId: "scenario-1",
            status: "accepted",
            createdAt: "2026-07-18T00:00:00Z",
            steps: [],
            disclaimer: "Educational estimate only.",
            kind: .harvest,
            executionStatus: .accepted,
            legs: [leg],
            rebalancingPlanIds: ["rebalance-1"]
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TaxActionPlanResponse.self, from: data)

        #expect(decoded == response)
    }

    @Test
    func `tax scenario round trips allocation impact`() throws {
        let response = TaxScenarioResponse(
            id: "scenario-1",
            createdAt: "2026-07-18T00:00:00Z",
            baseline: .init(
                currentYearTax: .init(amount: 1000, currency: "USD"),
                nextYearTax: .init(amount: 0, currency: "USD"),
                realizedLosses: .init(amount: 0, currency: "USD"),
                carryover: .init(amount: 0, currency: "USD"),
                feesAndSpread: .init(amount: 0, currency: "USD")
            ),
            harvestNow: .init(
                currentYearTax: .init(amount: 800, currency: "USD"),
                nextYearTax: .init(amount: 0, currency: "USD"),
                realizedLosses: .init(amount: 1000, currency: "USD"),
                carryover: .init(amount: 0, currency: "USD"),
                feesAndSpread: .init(amount: 5, currency: "USD")
            ),
            estimatedNetBenefit: .init(amount: 195, currency: "USD"),
            warnings: [],
            assumptions: [],
            allocationImpacts: [.init(
                portfolioId: "portfolio-1",
                portfolioValue: .init(amount: 100_000, currency: "USD"),
                maximumWeightChange: 0.05,
                changes: [
                    .init(instrumentId: "source", symbol: "VOO", beforeWeight: 0.20, afterWeight: 0.15),
                    .init(instrumentId: "replacement", symbol: "VTI", beforeWeight: 0, afterWeight: 0.05),
                ]
            )]
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TaxScenarioResponse.self, from: data)

        #expect(decoded == response)
    }
}
