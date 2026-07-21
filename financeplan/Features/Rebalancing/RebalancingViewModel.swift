import Factory
import Foundation
import Observation
import StockPlanShared

@MainActor @Observable
final class RebalancingViewModel {
  private(set) var overview: RebalancingOverview?
  private(set) var models: [AllocationModel] = []
  private(set) var simulation: RebalancingSimulation?
  private(set) var plans: [RebalancePlan] = []
  private(set) var history: RebalancingHistorySummary?
  private(set) var alerts: [RebalancingAlert] = []
  private(set) var isLoading = false
  private(set) var isSaving = false
  var pushEnabled = false
  var cashFlow = 0.0
  var errorMessage: String?

  let portfolio: Portfolio
  let service: any RebalancingServicing

  init(
    portfolio: Portfolio,
    service: any RebalancingServicing = Container.shared.rebalancingService()
  ) {
    self.portfolio = portfolio
    self.service = service
  }

  func load() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      async let overview = service.overview(portfolioId: portfolio.id)
      async let models = service.models(portfolioId: portfolio.id)
      async let plans = service.plans(portfolioId: portfolio.id)
      async let history = service.history(portfolioId: portfolio.id)
      async let alerts = service.alerts()
      async let preferences = service.preferences(portfolioId: portfolio.id)
      let values = try await (overview, models, plans, history, alerts, preferences)
      self.overview = values.0
      self.models = values.1
      self.plans = values.2
      self.history = values.3
      self.alerts = values.4.filter { $0.portfolioId == portfolio.id }
      self.pushEnabled = values.5.pushEnabled
      errorMessage = nil
    } catch is CancellationError {
      return
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func saveModel(_ draft: AllocationModelDraft) async -> Bool {
    await save {
      let request = try draft.request()
      if let id = draft.existingId {
        _ = try await service.updateModel(portfolioId: portfolio.id, modelId: id, request: request)
      } else {
        _ = try await service.createModel(portfolioId: portfolio.id, request: request)
      }
      simulation = nil
      await loadAfterMutation()
    }
  }

  func simulate(overrides: [RebalanceTradeOverride] = []) async {
    guard let model = overview?.model else { return }
    await save {
      simulation = try await service.simulate(
        portfolioId: portfolio.id,
        request: .init(
          modelId: model.id,
          modelRevision: model.revision,
          cashFlow: cashFlow,
          overrides: overrides
        )
      )
    }
  }

  func savePlan(name: String?, overrides: [RebalanceTradeOverride] = []) async -> Bool {
    guard let model = overview?.model else { return false }
    return await save {
      let tradeOverrides = overrides.isEmpty
        ? simulation?.trades.map {
          .init(symbol: $0.symbol, amount: $0.side == .buy ? $0.notional : -$0.notional)
        } ?? []
        : overrides
      let plan = try await service.createPlan(
        portfolioId: portfolio.id,
        request: .init(
          name: name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
          simulation: .init(
            modelId: model.id,
            modelRevision: model.revision,
            cashFlow: cashFlow,
            overrides: tradeOverrides
          )
        )
      )
      plans.insert(plan, at: 0)
    }
  }

  func complete(_ plan: RebalancePlan, note: String?) async {
    await save {
      let updated = try await service.completePlan(portfolioId: portfolio.id, planId: plan.id, note: note)
      if let index = plans.firstIndex(where: { $0.id == updated.id }) {
        plans[index] = updated
      }
      history = try await service.history(portfolioId: portfolio.id)
    }
  }

  func setPushEnabled(_ enabled: Bool) async {
    let previous = pushEnabled
    pushEnabled = enabled
    do {
      pushEnabled = try await service.updatePreferences(portfolioId: portfolio.id, enabled: enabled).pushEnabled
    } catch {
      pushEnabled = previous
      errorMessage = error.localizedDescription
    }
  }

  func acknowledge(_ alert: RebalancingAlert) async {
    do {
      let updated = try await service.acknowledge(alertId: alert.id)
      if let index = alerts.firstIndex(where: { $0.id == updated.id }) {
        alerts[index] = updated
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func loadAfterMutation() async {
    do {
      async let overview = service.overview(portfolioId: portfolio.id)
      async let models = service.models(portfolioId: portfolio.id)
      (self.overview, self.models) = try await (overview, models)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @discardableResult
  private func save(_ operation: () async throws -> Void) async -> Bool {
    guard !isSaving else { return false }
    isSaving = true
    defer { isSaving = false }
    do {
      try await operation()
      errorMessage = nil
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }
}

@MainActor @Observable
final class AllocationModelDraft {
  var existingId: String?
  var revision: Int?
  var name: String
  var groupingMode: AllocationGroupingMode
  var targetThresholdPercent: Double
  var totalThresholdPercent: Double
  var fractionalSharesEnabled: Bool
  var minimumTradeAmount: Double
  var flatFee: Double
  var buckets: [AllocationBucketDraft]

  init(model: AllocationModel? = nil) {
    existingId = model?.id
    revision = model?.revision
    name = model?.name ?? "Core allocation"
    groupingMode = model?.groupingMode ?? .custom
    targetThresholdPercent = Double(model?.defaultTargetThresholdBasisPoints ?? 500) / 100
    totalThresholdPercent = Double(model?.totalThresholdBasisPoints ?? 300) / 100
    fractionalSharesEnabled = model?.fractionalSharesEnabled ?? true
    minimumTradeAmount = model?.minimumTradeAmount ?? 10
    flatFee = model?.flatFee ?? 0
    buckets = model?.buckets.map(AllocationBucketDraft.init) ?? [
      AllocationBucketDraft(name: "Stocks", targetPercent: 60, leaves: [
        AllocationLeafDraft(name: "US total market", symbol: "VTI", targetPercent: 60),
      ]),
      AllocationBucketDraft(name: "Bonds", targetPercent: 40, leaves: [
        AllocationLeafDraft(name: "US bonds", symbol: "BND", targetPercent: 40),
      ]),
    ]
  }

  func request() throws -> AllocationModelUpsertRequest {
    let targetTotal = buckets.reduce(0) { $0 + basisPoints($1.targetPercent) }
    guard targetTotal == 10_000 else { throw DraftError("Bucket targets must total exactly 100%.") }
    let targets = try buckets.enumerated().map { bucketIndex, bucket in
      let bucketBasisPoints = basisPoints(bucket.targetPercent)
      let leaves = try bucket.leaves.enumerated().map { leafIndex, leaf in
        let leafBasisPoints = basisPoints(leaf.targetPercent)
        let symbol = leaf.isCash ? nil : leaf.symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard leaf.isCash || !(symbol?.isEmpty ?? true) else { throw DraftError("Every security target needs a symbol.") }
        return AllocationTargetLeaf(
          id: leaf.id.uuidString,
          kind: leaf.isCash ? .cash : .security,
          symbol: symbol,
          name: leaf.name.trimmingCharacters(in: .whitespacesAndNewlines),
          targetBasisPoints: leafBasisPoints,
          sortOrder: leafIndex
        )
      }
      guard leaves.reduce(0, { $0 + $1.targetBasisPoints }) == bucketBasisPoints else {
        throw DraftError("Targets inside \(bucket.name) must total \(bucket.targetPercent.formatted())%.")
      }
      return AllocationTargetBucket(
        id: bucket.id.uuidString,
        name: bucket.name.trimmingCharacters(in: .whitespacesAndNewlines),
        targetBasisPoints: bucketBasisPoints,
        sortOrder: bucketIndex,
        leaves: leaves
      )
    }
    return AllocationModelUpsertRequest(
      name: name,
      groupingMode: groupingMode,
      expectedRevision: revision,
      activate: true,
      defaultTargetThresholdBasisPoints: basisPoints(targetThresholdPercent),
      totalThresholdBasisPoints: basisPoints(totalThresholdPercent),
      fractionalSharesEnabled: fractionalSharesEnabled,
      quantityIncrement: fractionalSharesEnabled ? 0.001 : 1,
      minimumTradeAmount: minimumTradeAmount,
      flatFee: flatFee,
      buckets: targets
    )
  }

  func addBucket() {
    buckets.append(.init(name: "New group", targetPercent: 0, leaves: []))
  }

  private func basisPoints(_ percent: Double) -> Int {
    Int((percent * 100).rounded())
  }

  struct DraftError: LocalizedError {
    let message: String
    init(_ message: String) {
      self.message = message
    }

    var errorDescription: String? {
      message
    }
  }
}

@MainActor @Observable
final class AllocationBucketDraft: Identifiable {
  let id: UUID
  var name: String
  var targetPercent: Double
  var leaves: [AllocationLeafDraft]

  init(id: UUID = UUID(), name: String, targetPercent: Double, leaves: [AllocationLeafDraft]) {
    self.id = id
    self.name = name
    self.targetPercent = targetPercent
    self.leaves = leaves
  }

  convenience init(_ bucket: AllocationTargetBucket) {
    self.init(
      id: UUID(uuidString: bucket.id) ?? UUID(),
      name: bucket.name,
      targetPercent: Double(bucket.targetBasisPoints) / 100,
      leaves: bucket.leaves.map(AllocationLeafDraft.init)
    )
  }
}

@MainActor @Observable
final class AllocationLeafDraft: Identifiable {
  let id: UUID
  var name: String
  var symbol: String
  var targetPercent: Double
  var isCash: Bool

  init(
    id: UUID = UUID(),
    name: String,
    symbol: String = "",
    targetPercent: Double,
    isCash: Bool = false
  ) {
    self.id = id
    self.name = name
    self.symbol = symbol
    self.targetPercent = targetPercent
    self.isCash = isCash
  }

  convenience init(_ leaf: AllocationTargetLeaf) {
    self.init(
      id: UUID(uuidString: leaf.id) ?? UUID(),
      name: leaf.name,
      symbol: leaf.symbol ?? "",
      targetPercent: Double(leaf.targetBasisPoints) / 100,
      isCash: leaf.kind == .cash
    )
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
