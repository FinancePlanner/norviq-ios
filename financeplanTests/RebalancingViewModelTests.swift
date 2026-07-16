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

  @Test("Saving plan preserves edited trade overrides")
  func savePlanUsesExplicitOverrides() async throws {
    let service = RebalancingServiceMock()
    let model = RebalancingViewModel(portfolio: makePortfolio(), service: service)
    await model.load()
    await model.simulate()

    let overrides = [
      RebalanceTradeOverride(symbol: "VTI", amount: 250),
      RebalanceTradeOverride(symbol: "BND", amount: -125),
    ]

    let saved = await model.savePlan(name: "Custom plan", overrides: overrides)

    #expect(saved)
    let request = try #require(service.createPlanRequest)
    #expect(request.name == "Custom plan")
    #expect(request.simulation.overrides == overrides)
  }

  private func makePortfolio() -> Portfolio {
    Portfolio(
      id: "portfolio-1",
      ownerUserId: "owner",
      name: "Long-term",
      purpose: .personal,
      ownership: .individual,
      mode: .actual,
      baseCurrency: "USD",
      isDefault: true,
      currentUserRole: .owner,
      capabilities: PortfolioCapabilities(
        canView: true,
        canEdit: true,
        canManageMembers: true,
        canManageConnections: true,
        canArchive: false,
        canDelete: false
      ),
      createdAt: "2026-07-14T00:00:00Z"
    )
  }
}

private final class RebalancingServiceMock: RebalancingServicing, @unchecked Sendable {
  private let allocationModel = AllocationModel(
    id: "model-1",
    portfolioId: "portfolio-1",
    name: "Core",
    groupingMode: .custom,
    isActive: true,
    revision: 3,
    baseCurrency: "USD",
    buckets: [
      .init(
        id: "bucket-1",
        name: "Stocks",
        targetBasisPoints: 10_000,
        leaves: [
          .init(id: "leaf-1", kind: .security, symbol: "VTI", name: "US total market", targetBasisPoints: 10_000),
        ]
      ),
    ],
    createdAt: "2026-07-14T00:00:00Z"
  )

  private(set) var createPlanRequest: RebalancePlanCreateRequest?

  func models(portfolioId _: String) async throws -> [AllocationModel] {
    [allocationModel]
  }

  func createModel(portfolioId _: String, request _: AllocationModelUpsertRequest) async throws -> AllocationModel {
    throw RebalancingMockError.unexpectedCall
  }

  func updateModel(portfolioId _: String, modelId _: String, request _: AllocationModelUpsertRequest) async throws -> AllocationModel {
    throw RebalancingMockError.unexpectedCall
  }

  func overview(portfolioId: String) async throws -> RebalancingOverview {
    RebalancingOverview(
      portfolioId: portfolioId,
      model: allocationModel,
      baseCurrency: "USD",
      totalValue: 1_000,
      totalDriftBasisPoints: 100,
      severity: .warning,
      priceQuality: .live,
      rows: []
    )
  }

  func simulate(portfolioId: String, request _: RebalancingSimulationRequest) async throws -> RebalancingSimulation {
    RebalancingSimulation(
      portfolioId: portfolioId,
      modelId: allocationModel.id,
      modelRevision: allocationModel.revision,
      baseCurrency: "USD",
      totalValueBefore: 1_000,
      totalValueAfter: 1_000,
      driftBeforeBasisPoints: 100,
      driftAfterBasisPoints: 50,
      estimatedFees: 0,
      estimatedRealizedGainLoss: 0,
      trades: [
        RebalanceTrade(symbol: "VTI", side: .buy, quantity: 1, price: 100, notional: 100, estimatedFee: 0, currency: "USD"),
        RebalanceTrade(symbol: "BND", side: .sell, quantity: 1, price: 50, notional: 50, estimatedFee: 0, currency: "USD"),
      ],
      before: [],
      after: []
    )
  }

  func plans(portfolioId _: String) async throws -> [RebalancePlan] {
    []
  }

  func createPlan(portfolioId: String, request: RebalancePlanCreateRequest) async throws -> RebalancePlan {
    createPlanRequest = request
    return RebalancePlan(
      id: "plan-1",
      portfolioId: portfolioId,
      modelId: request.simulation.modelId,
      modelRevision: request.simulation.modelRevision,
      name: request.name,
      status: .draft,
      baseCurrency: "USD",
      driftBeforeBasisPoints: 100,
      driftAfterBasisPoints: 50,
      totalValue: 1_000,
      estimatedFees: 0,
      estimatedRealizedGainLoss: 0,
      trades: [],
      createdAt: "2026-07-14T00:00:00Z"
    )
  }

  func completePlan(portfolioId _: String, planId _: String, note _: String?) async throws -> RebalancePlan {
    throw RebalancingMockError.unexpectedCall
  }

  func history(portfolioId _: String) async throws -> RebalancingHistorySummary {
    RebalancingHistorySummary(completedCount: 0, averageDriftBeforeBasisPoints: 0, averageDriftAfterBasisPoints: 0)
  }

  func preferences(portfolioId: String) async throws -> RebalancingNotificationPreferences {
    RebalancingNotificationPreferences(portfolioId: portfolioId, pushEnabled: false)
  }

  func updatePreferences(portfolioId: String, enabled: Bool) async throws -> RebalancingNotificationPreferences {
    RebalancingNotificationPreferences(portfolioId: portfolioId, pushEnabled: enabled)
  }

  func alerts() async throws -> [RebalancingAlert] {
    []
  }

  func acknowledge(alertId _: String) async throws -> RebalancingAlert {
    throw RebalancingMockError.unexpectedCall
  }
}

private enum RebalancingMockError: Error {
  case unexpectedCall
}
