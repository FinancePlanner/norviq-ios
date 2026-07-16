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
  private(set) var financialGoals: [BudgetFinancialGoalWire] = []
  private(set) var portfolioLists: [BudgetPortfolioListWire] = []
  private(set) var isLoading = false
  private(set) var isCommitting = false
  private(set) var isSavingPolicy = false
  private var includesProData = false
  var adjustments: [String: Double] = [:]
  var categoryAlertThreshold = 15.0
  var totalAlertThreshold = 10.0
  var alertsEnabled = true
  var alertOnUnbudgeted = true
  var selectedFinancialGoalID: String? {
    didSet {
      guard let selectedFinancialGoalID,
            let goal = financialGoals.first(where: { $0.id == selectedFinancialGoalID })
      else { return }
      selectedPortfolioListID = goal.portfolioListId
    }
  }
  var selectedPortfolioListID: String?
  var errorMessage: String?
  var isShowingError: Bool {
    get { errorMessage != nil }
    set { if !newValue { errorMessage = nil } }
  }

  private let service: any ExpensesServicing

  init(
    service: any ExpensesServicing = Container.shared.expensesService(),
    dashboard: BudgetDriftDashboardWire? = nil
  ) {
    self.service = service
    self.dashboard = dashboard
  }

  func load(snapshotID: String, includePro: Bool) async {
    includesProData = includePro
    isLoading = true
    errorMessage = nil
    do {
      async let drift = service.getBudgetDrift(snapshotId: snapshotID)
      async let score = service.getBudgetDiscipline(months: 6)
      dashboard = try await drift
      discipline = try await score
      seedSuggestedAdjustments()
      history = includePro ? (try? await service.getBudgetReallocationHistory()) ?? [] : []
      if let snapshots = try? await service.getSnapshots(year: nil, month: nil),
         let snapshot = snapshots.first(where: { $0.id == snapshotID }) {
        categoryAlertThreshold = snapshot.categoryDriftThreshold
        totalAlertThreshold = snapshot.totalDriftThreshold
        alertsEnabled = snapshot.alertsEnabled
        alertOnUnbudgeted = snapshot.alertOnUnbudgeted
      }
      if includePro {
        financialGoals = (try? await service.getBudgetFinancialGoals()) ?? []
        portfolioLists = (try? await service.getBudgetPortfolioLists()) ?? []
      } else {
        financialGoals = []
        portfolioLists = []
      }
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
    guard let request = makePreviewRequest() else { preview = nil; return }
    do { preview = try await service.previewBudgetReallocation(request) }
    catch { errorMessage = error.localizedDescription }
  }

  @discardableResult
  func commit() async -> Bool {
    guard let dashboard else { return false }
    guard let request = makePreviewRequest() else { return false }
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

  func makePreviewRequest() -> BudgetReallocationPreviewRequestWire? {
    guard let dashboard else { return nil }
    let selectedAdjustments = adjustments.compactMap { id, value in
      value > 0 ? BudgetReallocationAdjustmentWire(planItemId: id, amount: value) : nil
    }
    guard !selectedAdjustments.isEmpty else { return nil }
    return BudgetReallocationPreviewRequestWire(
      snapshotId: dashboard.snapshotId,
      expectedRevision: dashboard.revision,
      adjustments: selectedAdjustments,
      financialGoalId: selectedFinancialGoalID,
      portfolioListId: selectedPortfolioListID
    )
  }

  @discardableResult
  func saveAlertPolicy() async -> Bool {
    guard let dashboard else { return false }
    guard categoryAlertThreshold.isFinite, totalAlertThreshold.isFinite,
          (0 ... 1_000).contains(categoryAlertThreshold), (0 ... 1_000).contains(totalAlertThreshold)
    else {
      errorMessage = "Enter alert thresholds between 0 and 1000 percent."
      return false
    }
    isSavingPolicy = true
    defer { isSavingPolicy = false }
    do {
      _ = try await service.updateBudgetAlertPolicy(
        snapshotId: dashboard.snapshotId,
        policy: BudgetAlertPolicy(
          categoryThreshold: categoryAlertThreshold,
          totalThreshold: totalAlertThreshold,
          alertsEnabled: alertsEnabled,
          alertOnUnbudgeted: alertOnUnbudgeted
        )
      )
      await load(snapshotID: dashboard.snapshotId, includePro: includesProData)
      return true
    } catch {
      errorMessage = error.localizedDescription
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
  let onOpenPolicy: () -> Void
  let onOpenPaywall: () -> Void

  var body: some View {
    GlassCard(cornerRadius: 18) {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Label("Budget discipline", systemImage: "gauge.with.dots.needle.50percent")
            .font(.headline)
          Spacer()
          if let level = viewModel.dashboard?.totalLevel { statusLabel(level) }
          Button("Alert policy", systemImage: "bell.badge") { onOpenPolicy() }
            .labelStyle(.iconOnly)
            .accessibilityHint("Configure budget drift thresholds and alerts")
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

        if !viewModel.financialGoals.isEmpty || !viewModel.portfolioLists.isEmpty {
          Section {
            Picker("Portfolio", selection: $viewModel.selectedPortfolioListID) {
              Text("General Investments bucket").tag(String?.none)
              ForEach(viewModel.portfolioLists) { portfolio in
                Text(portfolio.name).tag(String?.some(portfolio.id))
              }
            }
            Picker("Financial goal", selection: $viewModel.selectedFinancialGoalID) {
              Text("No linked goal").tag(String?.none)
              ForEach(viewModel.financialGoals) { goal in
                Text(goal.name).tag(String?.some(goal.id))
              }
            }
          } header: {
            Text("Investment destination")
          } footer: {
            Text("Selecting a goal also routes the contribution forecast to that goal’s portfolio.")
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
      .task(id: "\(viewModel.selectedTotal)-\(viewModel.selectedFinancialGoalID ?? "")-\(viewModel.selectedPortfolioListID ?? "")") { await viewModel.refreshPreview() }
      .alert("Could not update budget", isPresented: $viewModel.isShowingError) {
        Button("OK", role: .cancel) { viewModel.errorMessage = nil }
      } message: { Text(viewModel.errorMessage ?? "Please try again.") }
    }
  }

  private func adjustmentBinding(_ category: BudgetCategoryDriftWire) -> Binding<Double> {
    Binding(get: { viewModel.adjustments[category.id, default: 0] }, set: { viewModel.adjustments[category.id] = $0 })
  }
}

struct BudgetAlertPolicySheet: View {
  @Bindable var viewModel: BudgetDriftViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Category threshold", value: $viewModel.categoryAlertThreshold, format: .number)
            .keyboardType(.decimalPad)
          TextField("Total budget threshold", value: $viewModel.totalAlertThreshold, format: .number)
            .keyboardType(.decimalPad)
        } header: {
          Text("Drift thresholds")
        } footer: {
          Text("Thresholds are percentages above each category target and the total monthly plan.")
        }
        Section("Notifications") {
          Toggle("Enable drift alerts", isOn: $viewModel.alertsEnabled)
          Toggle("Alert on unbudgeted spending", isOn: $viewModel.alertOnUnbudgeted)
        }
      }
      .navigationTitle("Budget alerts")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { if await viewModel.saveAlertPolicy() { dismiss() } } }
            .disabled(viewModel.isSavingPolicy)
        }
      }
      .alert("Could not save alert policy", isPresented: $viewModel.isShowingError) {
        Button("OK", role: .cancel) { viewModel.errorMessage = nil }
      } message: { Text(viewModel.errorMessage ?? "Please try again.") }
    }
  }
}

struct ExpenseHistoryScreen: View {
  let activities: [BudgetActivity]
  @State private var search = ""
  @State private var pillar: BudgetPillar?

  private var filtered: [BudgetActivity] {
    activities.filter { activity in
      (search.isEmpty || activity.title.localizedStandardContains(search)) && (pillar == nil || activity.pillar == pillar)
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
