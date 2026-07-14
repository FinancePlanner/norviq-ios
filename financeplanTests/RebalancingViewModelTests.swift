import StockPlanShared
import Testing
@testable import financeplan

@MainActor
struct RebalancingViewModelTests {
  @Test("Default allocation draft creates an exact 60/40 nested model")
  func defaultDraft() throws {
    let request = try AllocationModelDraft().request()

    #expect(request.buckets.map(\.targetBasisPoints) == [6_000, 4_000])
    #expect(request.buckets.flatMap(\.leaves).map(\.symbol) == ["VTI", "BND"])
    #expect(request.buckets.flatMap(\.leaves).reduce(0) { $0 + $1.targetBasisPoints } == 10_000)
    #expect(request.activate)
  }

  @Test("Allocation draft rejects a model that does not total 100 percent")
  func invalidTotal() {
    let draft = AllocationModelDraft()
    draft.buckets[0].targetPercent = 50

    #expect(throws: (any Error).self) {
      try draft.request()
    }
  }

  @Test("Editing preserves optimistic concurrency revision")
  func preservesRevision() throws {
    let model = AllocationModel(
      id: "model-1",
      portfolioId: "portfolio-1",
      name: "Policy",
      groupingMode: .custom,
      isActive: true,
      revision: 7,
      baseCurrency: "USD",
      buckets: [
        .init(
          id: "bucket-1",
          name: "All",
          targetBasisPoints: 10_000,
          leaves: [
            .init(id: "leaf-1", kind: .security, symbol: "VT", name: "World", targetBasisPoints: 10_000),
          ]
        ),
      ],
      createdAt: "2026-07-14T00:00:00Z"
    )

    let request = try AllocationModelDraft(model: model).request()
    #expect(request.expectedRevision == 7)
  }
}
