import SwiftUI
import StockPlanShared
import Factory

struct TaxDashboardScreen: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme
  @State private var model: TaxDashboardViewModel

  init() {
    let container = Container.shared
    _model = State(initialValue: TaxDashboardViewModel(service: TaxService(
      environment: container.appEnvironment(),
      auth: container.authSessionManager()
    )))
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 16) {
          jurisdictionPicker
          if model.isLoading && model.dashboard == nil { loadingState }
          else if let dashboard = model.dashboard { summary(dashboard); opportunities(dashboard) }
          else { ContentUnavailableView("Tax estimate unavailable", systemImage: "building.columns") }
        }
        .padding()
      }
      .navigationTitle("Tax strategy")
      .refreshable { await model.load() }
      .task { await model.load() }
      .onChange(of: model.selectedJurisdiction) { _, _ in Task { await model.load() } }
      .alert("Tax strategy", isPresented: Binding(
        get: { model.errorMessage != nil },
        set: { if !$0 { model.errorMessage = nil } }
      )) { Button("OK", role: .cancel) {} } message: { Text(model.errorMessage ?? "") }
      .sheet(item: $model.scenario) { scenario in scenarioSheet(scenario) }
      .sheet(item: $model.actionPlan) { plan in actionPlanSheet(plan) }
    }
  }

  private var jurisdictionPicker: some View {
    Picker("Tax jurisdiction", selection: $model.selectedJurisdiction) {
      ForEach(TaxJurisdiction.allCases, id: \.self) { Text($0.rawValue).tag($0) }
    }
    .pickerStyle(.menu)
    .accessibilityHint("Changes the rules used for estimates")
  }

  private var loadingState: some View {
    VStack(spacing: 12) { ProgressView(); Text("Calculating from your tax lots…").foregroundStyle(.secondary) }
      .frame(maxWidth: .infinity, minHeight: 220)
  }

  private func summary(_ dashboard: TaxDashboardResponse) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Estimated tax drag").font(.subheadline).foregroundStyle(.secondary)
      Text(money(dashboard.summary.embeddedUnrealizedLiability)).font(.system(.largeTitle, design: .rounded, weight: .semibold))
      Divider()
      LabeledContent("Potential net benefit", value: money(dashboard.summary.estimatedNetBenefit))
      Text(dashboard.disclaimer).font(.caption).foregroundStyle(.secondary)
    }
    .padding(18)
    .background(AppTheme.Colors.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  private func opportunities(_ dashboard: TaxDashboardResponse) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Opportunities").font(.title2.bold())
      if dashboard.opportunities.isEmpty {
        Text(dashboard.profileComplete ? "No supported opportunities meet your threshold today." : "Complete your tax profile to unlock personalized opportunities.")
          .foregroundStyle(.secondary).padding(.vertical, 24)
      }
      ForEach(Array(dashboard.opportunities.enumerated()), id: \.element.id) { index, item in
        Button { Task { await model.simulate(item) } } label: {
          HStack(spacing: 14) {
            Image(systemName: item.status == .actionable ? "leaf.fill" : "exclamationmark.shield")
              .foregroundStyle(item.status == .actionable ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
              Text(item.symbol).font(.headline).foregroundStyle(.primary)
              Text("Loss \(money(item.unrealizedLoss)) · Benefit \(money(item.estimatedTaxBenefit))")
                .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
          }
          .padding(16)
          .background(AppTheme.Colors.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(item.status != .actionable)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.28, bounce: 0.08).delay(Double(index) * 0.035), value: dashboard.generatedAt)
      }
    }
  }

  private func scenarioSheet(_ scenario: TaxScenarioResponse) -> some View {
    NavigationStack {
      List {
        Section("Harvest now vs hold") {
          LabeledContent("Hold — current year", value: money(scenario.baseline.currentYearTax))
          LabeledContent("Harvest — current year", value: money(scenario.harvestNow.currentYearTax))
          LabeledContent("Estimated net benefit", value: money(scenario.estimatedNetBenefit))
        }
        Section { Text("This is an estimate, not tax advice. Review fees, replacement activity, and local rules.") }
      }
      .navigationTitle("Scenario")
      .safeAreaInset(edge: .bottom) {
        Button("Create action plan") { Task { await model.applyScenario() } }
          .buttonStyle(.borderedProminent).controlSize(.large).padding()
      }
    }
  }

  private func actionPlanSheet(_ plan: TaxActionPlanResponse) -> some View {
    NavigationStack {
      List(plan.steps, id: \.id) { step in Label { VStack(alignment: .leading) { Text(step.title); Text(step.detail).font(.caption).foregroundStyle(.secondary) } } icon: { Image(systemName: "circle") } }
        .navigationTitle("Action plan")
        .safeAreaInset(edge: .bottom) { Text("Norviq does not place trades. Complete these steps with your broker.").font(.footnote).foregroundStyle(.secondary).padding() }
    }
  }

  private func money(_ value: TaxMoney) -> String {
    value.amount.formatted(.currency(code: value.currency))
  }
}
