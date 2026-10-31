import Foundation
import Testing
@testable import StockPlanShared

struct RebalancingDTOsTests {
    @Test
    func `nested allocation model round trips without losing basis points`() throws {
        let model = fixtureModel()

        let data = try JSONEncoder().encode(model)
        let decoded = try JSONDecoder().decode(AllocationModel.self, from: data)

        #expect(decoded == model)
        #expect(decoded.buckets.reduce(0) { $0 + $1.targetBasisPoints } == 10000)
        #expect(decoded.buckets.flatMap(\.leaves).reduce(0) { $0 + $1.targetBasisPoints } == 10000)
    }

    @Test
    func `simulation preserves deterministic trade and drift snapshots`() throws {
        let trade = RebalanceTrade(
            symbol: "VT",
            side: .sell,
            quantity: 8,
            price: 100,
            notional: 800,
            estimatedFee: 0,
            estimatedCostBasis: 640,
            estimatedRealizedGainLoss: 160,
            currency: "USD"
        )
        let simulation = RebalancingSimulation(
            portfolioId: "portfolio-1",
            modelId: "model-1",
            modelRevision: 3,
            baseCurrency: "USD",
            totalValueBefore: 10000,
            totalValueAfter: 10000,
            driftBeforeBasisPoints: 800,
            driftAfterBasisPoints: 0,
            estimatedFees: 0,
            estimatedRealizedGainLoss: 160,
            trades: [trade],
            before: [],
            after: []
        )

        let data = try JSONEncoder().encode(simulation)
        #expect(try JSONDecoder().decode(RebalancingSimulation.self, from: data) == simulation)
    }

    @Test
    func `push registration remains backward compatible when capabilities are absent`() throws {
        let legacyJSON = #"{"deviceToken":"abc","platform":"ios","apnsEnvironment":"production","authorizationStatus":"authorized"}"#

        let decoded = try JSONDecoder().decode(
            PushDeviceRegistrationRequest.self,
            from: Data(legacyJSON.utf8)
        )

        #expect(decoded.capabilities == nil)
    }

    private func fixtureModel() -> AllocationModel {
        AllocationModel(
            id: "model-1",
            portfolioId: "portfolio-1",
            name: "60 / 40",
            groupingMode: .custom,
            isActive: true,
            revision: 3,
            baseCurrency: "USD",
            buckets: [
                AllocationTargetBucket(
                    id: "stocks",
                    name: "Stocks",
                    targetBasisPoints: 6000,
                    leaves: [
                        AllocationTargetLeaf(
                            id: "vt",
                            kind: .security,
                            symbol: "VT",
                            name: "Global stocks",
                            targetBasisPoints: 6000
                        ),
                    ]
                ),
                AllocationTargetBucket(
                    id: "bonds",
                    name: "Bonds",
                    targetBasisPoints: 4000,
                    leaves: [
                        AllocationTargetLeaf(
                            id: "bnd",
                            kind: .security,
                            symbol: "BND",
                            name: "US bonds",
                            targetBasisPoints: 4000
                        ),
                    ]
                ),
            ],
            createdAt: "2026-07-14T12:00:00Z"
        )
    }
}
