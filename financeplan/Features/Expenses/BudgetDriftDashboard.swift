import Factory
import Observation
import StockPlanShared
import SwiftUI

@Observable @MainActor
final class BudgetDriftViewModel {
  private(set) var dashboard: BudgetDriftDashboardWire?
  private(set) var discipline: BudgetDisciplineSummaryWire?
  private(set) var history: [BudgetReallocationEventWire] = []
  private(set) var preview: BudgetReallocationPreviewWire?
  private(set) var isLoading = false
  private(set) var isCommitting = false
  var adjustments: [String: Double] = [:]
  var errorMessage: String?

  private let service: any ExpensesServicing

  init(service: any ExpensesServicing = Container.shared.expensesService()) {
    self.service = service
  }

  func load(snapshotID: String, includePro: Bool) async {
    isLoading = true
    errorMessage = nil
    do {
      async let drift = service.getBudgetDrift(snapshotId: snapshotID)
      async let score = service.getBudgetDiscipline(months: 6)
      dashboard = try await drift
      discipline = try await score
      seedSuggestedAdjustments()
      history = includePro ? (try? await service.getBudgetReallocationHistory()) ?? [] : []
    } catch {
      errorMessage = error.localizedDescription
    }
    isLoading = false
  }

  var eligibleCategories: [BudgetCategoryDriftWire] {
    dashboard?.categories.filter {
      $0.allocationKind == .expense && $0.reallocationEligible && $0.level == .red && $0.targetAmount > 0
    } ?? []
  }

  var selectedTotal: Double { adjustments.values.reduce(0, +) }
  var annualImpact: Double { selectedTotal * 12 }

  func maximum(for category: BudgetCategoryDriftWire) -> Double {
    min(max(category.driftAmount, 0), category.targetAmount)
  }

  func refreshPreview() async {
    guard let dashboard else { return }
    let request = BudgetReallocationPreviewRequestWire(
      snapshotId: dashboard.snapshotId,
      expectedRevision: dashboard.revision,
      adjustments: adjustments.compactMap { id, value in
        value > 0 ? BudgetReallocationAdjustmentWire(planItemId: id, amount: value) : nil
      },
      financialGoalId: nil,
      portfolioListId: nil
    )
    guard !request.adjustments.isEmpty else { preview = nil; return }
    do { preview = try await service.previewBudgetReallocation(request) }
    catch { errorMessage = error.localizedDescription }
  }

  @discardableResult
  func commit() async -> Bool {
    guard let dashboard else { return false }
    let request = BudgetReallocationPreviewRequestWire(
      snapshotId: dashboard.snapshotId,
      expectedRevision: dashboard.revision,
      adjustments: adjustments.compactMap { id, value in
        value > 0 ? BudgetReallocationAdjustmentWire(planItemId: id, amount: value) : nil
      },
      financialGoalId: nil,
      portfolioListId: nil
    )
    guard !request.adjustments.isEmpty else { return false }
    isCommitting = true
    defer { isCommitting = false }
    do {
      _ = try await service.commitBudgetReallocation(
        BudgetReallocationCommitRequestWire(requestId: UUID().uuidString, preview: request)
      )
      await load(snapshotID: dashboard.snapshotId, includePro: true)
      return true
    } catch {
      errorMessage = error.localizedDescription
      if (error as? ExpensesHTTPClient.Error)?.statusCode == 409 {
        await load(snapshotID: dashboard.snapshotId, includePro: true)
      }
      return false
    }
  }

  private func seedSuggestedAdjustments() {
    adjustments = Dictionary(uniqueKeysWithValues: eligibleCategories.map { ($0.id, maximum(for: $0)) })
  }
}

struct BudgetDriftDashboardCard: View {
  let viewModel: BudgetDriftViewModel
  let isPro: Bool
  let onOpenSimulator: () -> Void
  let onOpenPaywall: () -> Void

  var body: some View {
    GlassCard(cornerRadius: 18) {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Label("Budget discipline", systemImage: "gauge.with.dots.needle.50percent")
            .font(.headline)
          Spacer()
          if let level = viewModel.dashboard?.totalLevel { statusLabel(level) }
        }

        if viewModel.isLoading {
          ProgressView().frame(maxWidth: .infinity).accessibilityLabel("Loading budget drift")
        } else if let dashboard = viewModel.dashboard {
          totalSummary(dashboard)
          ForEach(dashboard.categories.filter { $0.allocationKind == .expense }.prefix(5)) { category in
            categoryRow(category, currency: dashboard.currencyCode)
          }

          if let discipline = viewModel.discipline {
            Divider()
            HStack(spacing: 18) {
              metric(title: "Score", value: discipline.currentScore.map { "\(Int($0.rounded()))/100" } ?? "—")
              metric(title: "Streak", value: "\(discipline.completedMonthStreak) mo")
              metric(title: "On plan", value: "\(discipline.compliantMonths)/\(discipline.evaluatedMonths)")
            }
            .accessibilityElement(children: .combine)
          }

          if !viewModel.eligibleCategories.isEmpty {
            Button {
              isPro ? onOpenSimulator() : onOpenPaywall()
            } label: {
              Label("View reallocation plan", systemImage: "arrow.triangle.swap")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Moves next month's spending targets into the Investments budget; no money is transferred")
          }
        } else {
          ContentUnavailableView("Drift unavailable", systemImage: "chart.bar.xaxis", description: Text(viewModel.errorMessage ?? "Add targets to calculate drift."))
        }
      }
    }
  }

  private func totalSummary(_ dashboard: BudgetDriftDashboardWire) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        Text(dashboard.totalActual, format: .currency(code: dashboard.currencyCode)).font(.title3.bold())
        Text("of \(dashboard.totalTarget.formatted(.currency(code: dashboard.currencyCode)))").foregroundStyle(.secondary)
        Spacer()
      }
      ProgressView(value: dashboard.totalTarget > 0 ? min(dashboard.totalActual / dashboard.totalTarget, 1) : 1)
        .tint(color(dashboard.totalLevel))
      if dashboard.lostInvestmentCapital > 0 {
        Text("Overspending has reduced this month's available investment capital by \(dashboard.lostInvestmentCapital.formatted(.currency(code: dashboard.currencyCode))).")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private func categoryRow(_ category: BudgetCategoryDriftWire, currency: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Image(systemName: icon(category.level)).foregroundStyle(color(category.level)).accessibilityHidden(true)
        Text(category.title).font(.subheadline.weight(.medium)).lineLimit(1)
        Spacer()
        Text(category.driftAmount, format: .currency(code: currency)).font(.subheadline.monospacedDigit())
      }
      ProgressView(value: category.targetAmount > 0 ? min(category.actualAmount / category.targetAmount, 1) : 1)
        .tint(color(category.level))
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(category.title), \(category.level.rawValue), spent \(category.actualAmount.formatted(.currency(code: currency))) against \(category.targetAmount.formatted(.currency(code: currency)))")
  }

  private func statusLabel(_ level: BudgetDriftLevelWire) -> some View {
    Label(level.rawValue.capitalized, systemImage: icon(level))
      .font(.caption.weight(.semibold)).foregroundStyle(color(level))
  }
  private func metric(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) { Text(value).font(.subheadline.bold()); Text(title).font(.caption).foregroundStyle(.secondary) }
  }
  private func color(_ level: BudgetDriftLevelWire) -> Color { switch level { case .green: .green; case .yellow: .orange; case .red: .red } }
  private func icon(_ level: BudgetDriftLevelWire) -> String { switch level { case .green: "checkmark.circle.fill"; case .yellow: "exclamationmark.circle.fill"; case .red: "exclamationmark.octagon.fill" } }
}

struct BudgetReallocationSimulatorSheet: View {
  @Bindable var viewModel: BudgetDriftViewModel
  let onCommitted: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          if viewModel.eligibleCategories.isEmpty {
            ContentUnavailableView("No reallocation needed", systemImage: "checkmark.circle", description: Text("No eligible category is beyond its alert threshold."))
          } else {
            ForEach(viewModel.eligibleCategories) { category in
              VStack(alignment: .leading, spacing: 10) {
                HStack { Text(category.title); Spacer(); Text(viewModel.adjustments[category.id, default: 0], format: .currency(code: viewModel.dashboard?.currencyCode ?? "USD")).monospacedDigit() }
                Slider(value: adjustmentBinding(category), in: 0 ... max(viewModel.maximum(for: category), 0.01), step: 1)
                  .accessibilityLabel("Reduce \(category.title) next month")
              }
            }
          }
        } header: { Text("Next-month adjustments") }
          footer: { Text("These changes update budget targets and forecasts only. Norviq never transfers money or places trades.") }

        Section("Impact") {
          LabeledContent("Added monthly investment", value: viewModel.selectedTotal.formatted(.currency(code: viewModel.dashboard?.currencyCode ?? "USD")))
          LabeledContent("Estimated annual runway", value: viewModel.annualImpact.formatted(.currency(code: viewModel.dashboard?.currencyCode ?? "USD")))
          if let preview = viewModel.preview {
            LabeledContent("Effective month", value: preview.effectiveMonth)
            ForEach(preview.warnings, id: \.self) { Label($0, systemImage: "exclamationmark.triangle") }
          }
        }
      }
      .navigationTitle("Reallocation plan")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Commit") {
            Task { if await viewModel.commit() { onCommitted(); dismiss() } }
          }
          .disabled(viewModel.selectedTotal <= 0 || viewModel.isCommitting)
        }
      }
      .task(id: viewModel.selectedTotal) { await viewModel.refreshPreview() }
      .alert("Could not update budget", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
        Button("OK", role: .cancel) { viewModel.errorMessage = nil }
      } message: { Text(viewModel.errorMessage ?? "Please try again.") }
    }
  }

  private func adjustmentBinding(_ category: BudgetCategoryDriftWire) -> Binding<Double> {
    Binding(get: { viewModel.adjustments[category.id, default: 0] }, set: { viewModel.adjustments[category.id] = $0 })
  }
}

struct ExpenseHistoryScreen: View {
  let activities: [BudgetActivity]
  @State private var search = ""
  @State private var pillar: BudgetPillar?

  private var filtered: [BudgetActivity] {
    activities.filter { activity in
      (search.isEmpty || activity.title.localizedCaseInsensitiveContains(search)) && (pillar == nil || activity.pillar == pillar)
    }
  }

  var body: some View {
    List {
      ForEach(filtered) { activity in
        VStack(alignment: .leading, spacing: 4) {
          HStack { Text(activity.title); Spacer(); Text(activity.amount.currency).monospacedDigit() }
          Text(activity.occurredOn, format: .dateTime.day().month().year()).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
      }
    }
    .navigationTitle("Spending log")
    .searchable(text: $search, prompt: "Search expenses")
    .toolbar {
      Menu("Filter", systemImage: "line.3.horizontal.decrease.circle") {
        Button("All categories") { pillar = nil }
        ForEach(BudgetPillar.allCases, id: \.rawValue) { value in Button(value.title) { pillar = value } }
      }
    }
    .overlay { if filtered.isEmpty { ContentUnavailableView.search(text: search) } }
  }
}
