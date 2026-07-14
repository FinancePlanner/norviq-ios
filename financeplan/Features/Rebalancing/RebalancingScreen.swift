import Charts
import Foundation
import StockPlanShared
import SwiftUI

struct RebalancingScreen: View {
  @State private var model: RebalancingViewModel
  @State private var isEditingTargets = false
  @State private var isSimulating = false
  @State private var completionPlan: RebalancePlan?

  init(portfolio: Portfolio) {
    _model = State(initialValue: RebalancingViewModel(portfolio: portfolio))
  }

  var body: some View {
    List {
      if let overview = model.overview {
        summary(overview)
        if overview.model != nil {
          allocationCharts(overview)
          driftSection(overview)
        } else {
          Section {
            ContentUnavailableView(
              "Set an allocation target",
              systemImage: "scope",
              description: Text("Define the mix you want Norviq to monitor for this portfolio.")
            )
            Button("Create 60/40 model") { isEditingTargets = true }
          }
        }
        if !overview.warnings.isEmpty {
          warningSection(overview.warnings)
        }
      }

      if !model.alerts.filter({ $0.status != .resolved }).isEmpty {
        alertsSection
      }
      disciplineSection
      planHistorySection
    }
    .overlay {
      if model.isLoading, model.overview == nil {
        ProgressView()
      }
    }
    .navigationTitle("Rebalancing")
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Edit targets", systemImage: "slider.horizontal.3") { isEditingTargets = true }
          .disabled(!model.portfolio.capabilities.canEdit)
      }
    }
    .safeAreaInset(edge: .bottom) {
      if model.overview?.model != nil {
        Button {
          isSimulating = true
        } label: {
          Label("Build rebalancing plan", systemImage: "arrow.triangle.2.circlepath")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding()
        .background(.bar)
      }
    }
    .task { await model.load() }
    .refreshable { await model.load() }
    .sheet(isPresented: $isEditingTargets) {
      AllocationModelEditor(
        draft: AllocationModelDraft(model: model.overview?.model),
        isSaving: model.isSaving,
        onSave: { await model.saveModel($0) }
      )
    }
    .sheet(isPresented: $isSimulating) {
      RebalancingSimulator(model: model)
    }
    .sheet(item: $completionPlan) { plan in
      CompleteRebalancingPlanSheet(plan: plan) { note in
        await model.complete(plan, note: note)
      }
    }
    .alert("Couldn’t complete the request", isPresented: errorBinding) {
      Button("OK") { model.errorMessage = nil }
    } message: {
      Text(model.errorMessage ?? "Please try again.")
    }
  }

  private func summary(_ overview: RebalancingOverview) -> some View {
    Section {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 4) {
            Text(overview.totalValue, format: .currency(code: overview.baseCurrency))
              .font(.title2.weight(.semibold))
            Text("Current portfolio value").font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 4) {
            Text(Double(overview.totalDriftBasisPoints) / 100, format: .number.precision(.fractionLength(2))) + Text("%")
            Text("total drift").font(.caption).foregroundStyle(.secondary)
          }
        }
        Label(severityLabel(overview.severity), systemImage: severityIcon(overview.severity))
          .font(.subheadline.weight(.medium))
          .foregroundStyle(severityColor(overview.severity))
        if overview.priceQuality != .live {
          Label("Plan generation is limited until valuation data is complete.", systemImage: "exclamationmark.triangle")
            .font(.caption).foregroundStyle(.orange)
        }
      }
      .accessibilityElement(children: .combine)
    }
  }

  private func allocationCharts(_ overview: RebalancingOverview) -> some View {
    Section("Allocation") {
      HStack(spacing: 12) {
        allocationChart(title: "Current", rows: overview.rows, current: true)
        allocationChart(title: "Target", rows: overview.rows, current: false)
      }
      .frame(height: 170)
      .accessibilityElement(children: .contain)
    }
  }

  private func allocationChart(
    title: String,
    rows: [RebalancingAllocationRow],
    current: Bool
  ) -> some View {
    VStack {
      Chart(rows) { row in
        SectorMark(
          angle: .value("Allocation", current ? row.currentBasisPoints : row.targetBasisPoints),
          innerRadius: .ratio(0.58),
          angularInset: 1.5
        )
        .foregroundStyle(by: .value("Group", row.label))
      }
      .chartLegend(.hidden)
      Text(title).font(.caption.weight(.medium))
    }
    .accessibilityLabel("\(title) allocation")
    .accessibilityValue(
      rows.map { "\($0.label) \(Double(current ? $0.currentBasisPoints : $0.targetBasisPoints) / 100) percent" }.joined(
        separator: ", "
      )
    )
  }

  private func driftSection(_ overview: RebalancingOverview) -> some View {
    Section("Drift by group") {
      ForEach(overview.rows) { row in
        DisclosureGroup {
          ForEach(row.children) { child in DriftRow(row: child, currency: overview.baseCurrency) }
        } label: {
          DriftRow(row: row, currency: overview.baseCurrency)
        }
      }
    }
  }

  private func warningSection(_ warnings: [RebalancingValuationWarning]) -> some View {
    Section("Data checks") {
      ForEach(warnings) { warning in
        Label(warning.message, systemImage: "exclamationmark.triangle")
          .font(.footnote).foregroundStyle(.orange)
      }
    }
  }

  private var alertsSection: some View {
    Section("Drift alerts") {
      ForEach(model.alerts.filter { $0.status != .resolved }) { alert in
        Button {
          Task { await model.acknowledge(alert) }
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(alert.scopeName).foregroundStyle(.primary)
            Text("\(signedPercent(alert.driftBasisPoints)) drift · \(percent(alert.thresholdBasisPoints)) threshold")
              .font(.caption).foregroundStyle(.secondary)
          }
        }
        .disabled(alert.status == .acknowledged)
      }
      Toggle("Push drift alerts", isOn: Binding(
        get: { model.pushEnabled },
        set: { enabled in Task { await model.setPushEnabled(enabled) } }
      ))
    }
  }

  private var disciplineSection: some View {
    Section("Discipline") {
      if let history = model.history {
        LabeledContent("Completed rebalances", value: history.completedCount.formatted())
        LabeledContent("Average drift before", value: percent(history.averageDriftBeforeBasisPoints))
        LabeledContent("Average drift after", value: percent(history.averageDriftAfterBasisPoints))
        if let days = history.averageDaysBetweenRebalances {
          LabeledContent("Average cadence", value: "\(days.formatted(.number.precision(.fractionLength(0)))) days")
        }
      }
    }
  }

  private var planHistorySection: some View {
    Section("Plans") {
      if model.plans.isEmpty {
        Text("Saved plans will appear here.").foregroundStyle(.secondary)
      }
      ForEach(model.plans) { plan in
        VStack(alignment: .leading, spacing: 5) {
          HStack {
            Text(plan.name ?? "Rebalancing plan").font(.headline)
            Spacer()
            Text(plan.status.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
          }
          Text(
            "\(plan.trades.count) trades · \(percent(plan.driftBeforeBasisPoints)) → \(percent(plan.driftAfterBasisPoints))"
          )
          .font(.caption).foregroundStyle(.secondary)
          if plan.status == .draft || plan.status == .exported {
            Button("Mark completed") { completionPlan = plan }
              .font(.subheadline)
          }
        }
      }
    }
  }

  private var errorBinding: Binding<Bool> {
    Binding(get: { model.errorMessage != nil }, set: {
      if !$0 {
        model.errorMessage = nil
      }
    })
  }
}

private struct DriftRow: View {
  let row: RebalancingAllocationRow
  let currency: String

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 3) {
        Text(row.label)
        Text(
          "\(Double(row.currentBasisPoints) / 100, format: .number.precision(.fractionLength(1)))% / \(Double(row.targetBasisPoints) / 100, format: .number.precision(.fractionLength(1)))% target"
        )
        .font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 3) {
        Text(signedPercent(row.driftBasisPoints)).foregroundStyle(severityColor(row.severity))
        Text(row.driftValue, format: .currency(code: currency)).font(.caption).foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

private struct AllocationModelEditor: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var draft: AllocationModelDraft
  let isSaving: Bool
  let onSave: (AllocationModelDraft) async -> Bool

  var body: some View {
    NavigationStack {
      Form {
        Section("Model") {
          TextField("Name", text: $draft.name)
          Picker("Grouping", selection: $draft.groupingMode) {
            Text("Holdings").tag(AllocationGroupingMode.holding)
            Text("Sectors").tag(AllocationGroupingMode.sector)
            Text("Custom groups").tag(AllocationGroupingMode.custom)
          }
          LabeledContent("Total drift alert") {
            TextField("Percent", value: $draft.totalThresholdPercent, format: .number)
              .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
          }
          LabeledContent("Asset drift alert") {
            TextField("Percent", value: $draft.targetThresholdPercent, format: .number)
              .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
          }
        }
        ForEach(draft.buckets) { bucket in
          AllocationBucketEditor(bucket: bucket) {
            draft.buckets.removeAll { $0.id == bucket.id }
          }
        }
        Section {
          Button("Add group", systemImage: "plus") { draft.addBucket() }
        }
        Section("Trade assumptions") {
          Toggle("Fractional shares", isOn: $draft.fractionalSharesEnabled)
          LabeledContent("Minimum trade") {
            TextField("Amount", value: $draft.minimumTradeAmount, format: .number)
              .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
          }
          LabeledContent("Fee per trade") {
            TextField("Fee", value: $draft.flatFee, format: .number)
              .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
          }
        }
      }
      .navigationTitle(draft.existingId == nil ? "New target" : "Edit target")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task {
            if await onSave(draft) {
              dismiss()
            }
          } }
          .disabled(isSaving || draft.buckets.isEmpty)
        }
      }
    }
  }
}

private struct AllocationBucketEditor: View {
  @Bindable var bucket: AllocationBucketDraft
  let remove: () -> Void

  var body: some View {
    Section {
      TextField("Group name", text: $bucket.name)
      LabeledContent("Group target") {
        TextField("Percent", value: $bucket.targetPercent, format: .number)
          .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
      }
      ForEach(bucket.leaves) { leaf in
        AllocationLeafEditor(leaf: leaf) { bucket.leaves.removeAll { $0.id == leaf.id } }
      }
      Button("Add holding", systemImage: "plus") {
        bucket.leaves.append(.init(name: "", targetPercent: 0))
      }
      Button("Remove group", role: .destructive, action: remove)
    } header: {
      Text(bucket.name.isEmpty ? "Allocation group" : bucket.name)
    }
  }
}

private struct AllocationLeafEditor: View {
  @Bindable var leaf: AllocationLeafDraft
  let remove: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      HStack {
        TextField("Name", text: $leaf.name)
        if !leaf.isCash {
          TextField("Ticker", text: $leaf.symbol).textInputAutocapitalization(.characters).frame(maxWidth: 90)
        }
      }
      HStack {
        Toggle("Cash", isOn: $leaf.isCash).labelsHidden()
        Text(leaf.isCash ? "Cash" : "Security").font(.caption).foregroundStyle(.secondary)
        Spacer()
        TextField("Target %", value: $leaf.targetPercent, format: .number)
          .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 100)
        Button("Remove", systemImage: "minus.circle", role: .destructive, action: remove).labelStyle(.iconOnly)
      }
    }
  }
}

private struct RebalancingSimulator: View {
  @Environment(\.dismiss) private var dismiss
  let model: RebalancingViewModel
  @State private var overrides: [String: Double] = [:]
  @State private var planName = ""

  var body: some View {
    NavigationStack {
      List {
        Section("What if") {
          LabeledContent("Add or withdraw cash") {
            TextField("Amount", value: Binding(
              get: { model.cashFlow },
              set: { model.cashFlow = $0 }
            ), format: .number)
              .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
          }
          Button("Recalculate") { Task { await recalculate() } }.disabled(model.isSaving)
        }
        if let simulation = model.simulation {
          Section("Result") {
            LabeledContent("Drift before", value: percent(simulation.driftBeforeBasisPoints))
            LabeledContent("Drift after", value: percent(simulation.driftAfterBasisPoints))
            LabeledContent(
              "Estimated fees",
              value: simulation.estimatedFees.formatted(.currency(code: simulation.baseCurrency))
            )
            LabeledContent(
              "Estimated gain/loss",
              value: simulation.estimatedRealizedGainLoss.formatted(.currency(code: simulation.baseCurrency))
            )
          }
          Section("Proposed trades") {
            ForEach(simulation.trades) { trade in
              VStack(alignment: .leading, spacing: 7) {
                HStack {
                  Text(trade.side.rawValue.uppercased()).font(.caption.weight(.bold))
                    .foregroundStyle(trade.side == .buy ? Color.green : Color.orange)
                  Text(trade.symbol).font(.headline)
                  Spacer()
                  Text(trade.notional, format: .currency(code: trade.currency))
                }
                Text(
                  "\(trade.quantity.formatted(.number.precision(.fractionLength(0...4)))) shares @ \(trade.price.formatted(.currency(code: trade.currency)))"
                )
                .font(.caption).foregroundStyle(.secondary)
                TextField("Trade amount", value: amountBinding(trade), format: .number)
                  .keyboardType(.decimalPad)
              }
            }
          }
          Section("Save planning record") {
            TextField("Plan name (optional)", text: $planName)
            Button("Save plan") {
              Task {
                if await model.savePlan(name: planName) {
                  dismiss()
                }
              }
            }
            .disabled(simulation.trades.isEmpty || model.isSaving)
          }
          Section {
            Text(
              "Norviq does not place orders or change your holdings. Costs and tax impact are estimates; review the exported instructions before trading."
            )
            .font(.footnote).foregroundStyle(.secondary)
          }
        }
      }
      .navigationTitle("Rebalancing plan")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
      .task {
        if model.simulation == nil {
          await model.simulate()
        }; seedOverrides() }
    }
  }

  private func amountBinding(_ trade: RebalanceTrade) -> Binding<Double> {
    Binding(
      get: { overrides[trade.symbol] ?? (trade.side == .buy ? trade.notional : -trade.notional) },
      set: { overrides[trade.symbol] = $0 }
    )
  }

  private func recalculate() async {
    await model.simulate(overrides: overrides.map { .init(symbol: $0.key, amount: $0.value) })
    seedOverrides()
  }

  private func seedOverrides() {
    guard overrides.isEmpty else { return }
    for trade in model.simulation?.trades ?? [] {
      overrides[trade.symbol] = trade.side == .buy ? trade.notional : -trade.notional
    }
  }
}

private struct CompleteRebalancingPlanSheet: View {
  @Environment(\.dismiss) private var dismiss
  let plan: RebalancePlan
  let complete: (String?) async -> Void
  @State private var note = ""

  var body: some View {
    NavigationStack {
      Form {
        Text("This logs your discipline history only. It does not modify positions or submit orders.")
          .font(.footnote).foregroundStyle(.secondary)
        TextField("Completion note (optional)", text: $note, axis: .vertical)
      }
      .navigationTitle("Mark completed")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Complete") { Task { await complete(note.isEmpty ? nil : note); dismiss() } }
        }
      }
    }
  }
}

private func percent(_ basisPoints: Int) -> String {
  String(format: "%.2f%%", Double(basisPoints) / 100)
}

private func signedPercent(_ basisPoints: Int) -> String {
  let prefix = basisPoints > 0 ? "+" : ""
  return "\(prefix)\(percent(basisPoints))"
}

private func severityLabel(_ severity: RebalancingDriftSeverity) -> String {
  switch severity {
  case .balanced: "Within target"
  case .warning: "Approaching threshold"
  case .breached: "Rebalancing threshold exceeded"
  case .unavailable: "Drift unavailable"
  }
}

private func severityIcon(_ severity: RebalancingDriftSeverity) -> String {
  switch severity {
  case .balanced: "checkmark.circle.fill"
  case .warning: "exclamationmark.circle.fill"
  case .breached: "exclamationmark.triangle.fill"
  case .unavailable: "questionmark.circle.fill"
  }
}

private func severityColor(_ severity: RebalancingDriftSeverity) -> Color {
  switch severity {
  case .balanced: .green
  case .warning: .orange
  case .breached: .red
  case .unavailable: .secondary
  }
}
