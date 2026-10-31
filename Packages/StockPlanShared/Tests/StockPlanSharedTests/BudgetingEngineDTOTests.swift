import Foundation
import Testing
@testable import StockPlanShared

@Suite("Budgeting engine contracts")
struct BudgetingEngineDTOTests {
    @Test("legacy snapshot and plan item payloads retain safe defaults")
    func legacyPayloadDefaults() throws {
        let snapshot = try JSONDecoder().decode(
            BudgetSnapshotResponse.self,
            from: Data(#"{"id":"1","monthStart":"2026-07-01","netSalary":4000,"targetShares":{}}"#.utf8)
        )
        #expect(snapshot.currencyCode == "USD")
        #expect(snapshot.categoryDriftThreshold == 15)
        #expect(snapshot.revision == 0)

        let item = try JSONDecoder().decode(
            BudgetPlanItemResponse.self,
            from: Data(
                #"{"id":"2","snapshotId":"1","title":"Dining","plannedAmount":150,"pillar":"fun","splitMode":"personal","userSharePercent":100}"#
                    .utf8
            )
        )
        #expect(item.targetType == .fixed)
        #expect(item.allocationKind == .expense)
        #expect(item.reallocationEligible == false)
    }

    @Test("reallocation preview round trips")
    func reallocationRoundTrip() throws {
        let request = BudgetReallocationCommitRequest(
            requestId: UUID().uuidString,
            preview: .init(
                snapshotId: UUID().uuidString,
                expectedRevision: 3,
                adjustments: [.init(planItemId: UUID().uuidString, amount: 60)]
            )
        )
        let data = try JSONEncoder().encode(request)
        #expect(try JSONDecoder().decode(BudgetReallocationCommitRequest.self, from: data) == request)
    }
}
