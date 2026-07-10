import SwiftUI
import Charts
import Observation
import OSLog
import StockPlanShared
import Factory

private let homePerformanceLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
  category: "HomePerformance"
)

@MainActor
struct DashboardRoot: View {
  @Environment(\.colorScheme) private var colorScheme
  @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
  @Binding var selectedTab: HomeTab
  @Binding var isSettingsPresented: Bool
  @Bindable var budgetStore: BudgetPlannerViewModel
  @State private var searchViewModel = AssetSearchViewModel()
  @State private var activityViewModel = ActivityViewModel()
  @State private var focusPointsViewModel = FocusPointsViewModel()
  @State private var dashboardInsights: DashboardInsightsResponse?
  @State private var isInsightsLoading = false
  @State private var insightsLoadFailed = false
  @State private var isHomeMetricsLoading = false
  @State private var portfolioTotalValue: Double = 0
  @State private var spendingTotalValue: Double = 0
  @State private var portfolioDeltaPercent: Double?
  @State private var spendingDeltaPercent: Double?
  @State private var portfolioChartPoints: [ChartDataPoint] = []
  @State private var spendingChartPoints: [ChartDataPoint] = []
  @State private var isQuickAddPresented = false
  @State private var isChartBuilderPresented = false
  @State private var hasLoadedContent = false

  private let dashboardService: any DashboardServicing = Container.shared.dashboardService()
  private let expensesService: any ExpensesServicing = Container.shared.expensesService()
  private let stockService: any StockServicing = Container.shared.stockService()

  private var appLanguage: AppLanguage {
    AppLanguage.from(appLanguageRawValue)
  }

  private var insightCards: [InsightCard] {
    guard let insights = dashboardInsights else {
        return []
    }

    return [
        .init(
            title: String(localized: "Savings rate"),
            value: "\(Int(insights.savingsRate))%",
            detail: String(localized: "Based on monthly planned vs actuals."),
            symbol: "arrow.down.circle",
            tint: AppTheme.Colors.success
        ),
        .init(
            title: String(localized: "Budget streak"),
            value: String(localized: "\(insights.budgetStreak) months"),
            detail: String(localized: "Staying under your spending plan."),
            symbol: "flame",
            tint: .orange
        ),
        .init(
            title: String(localized: "Watchlist"),
            value: String(localized: "\(insights.watchlistCount) names"),
            detail: String(localized: "Review candidates before earnings."),
            symbol: "star",
            tint: .indigo
        ),
        .init(
            title: String(localized: "Cash buffer"),
            value: insights.cashBuffer.formatted(.currency(code: "USD").presentation(.narrow)),
            detail: String(localized: "Enough for short-term volatility."),
            symbol: "shield",
            tint: AppTheme.Colors.tint(for: .light)
        )
    ]
  }

  private var greetingText: String {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 5..<12: return String(localized: "Good morning")
    case 12..<17: return String(localized: "Good afternoon")
    case 17..<22: return String(localized: "Good evening")
    default: return String(localized: "Good night")
    }
  }

  private var isHomeMetricsRedacted: Bool {
    isHomeMetricsLoading && !hasLoadedContent
  }

  private var isSearchResultsVisible: Bool {
    !searchViewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        Group {
          DashboardContentSection(
            portfolioTotalValue: portfolioTotalValue,
            spendingTotalValue: spendingTotalValue,
            portfolioDeltaPercent: portfolioDeltaPercent,
            spendingDeltaPercent: spendingDeltaPercent,
            portfolioChartPoints: portfolioChartPoints,
            spendingChartPoints: spendingChartPoints,
            isHomeMetricsRedacted: isHomeMetricsRedacted,
            isSearchResultsVisible: isSearchResultsVisible,
            searchViewModel: searchViewModel,
            activityViewModel: activityViewModel,
            recentExpenses: budgetStore.recentExpenseActivities,
            financialHealth: dashboardInsights?.financialHealth,
            isFinancialHealthLoading: isInsightsLoading,
            financialHealthUnavailable: insightsLoadFailed,
            insightCards: insightCards,
            focusPointsViewModel: focusPointsViewModel,
            onPortfolioTap: showPortfolioTab,
            onExpensesTap: showExpensesTab,
            onReportsTap: showReportsTab,
            onChartBuilderTap: presentChartBuilder,
            onQuickAddTap: presentQuickAdd
          )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        // Center the dashboard column on iPad rather than stretching data
        // edge-to-edge (Guideline 4). Background below still fills the screen.
        .maxContentWidth(regularSizeClass: ContentWidth.dense)
      }
      .background(MeshGradientBackground())
      .navigationTitle(greetingText)
      .navigationBarTitleDisplayMode(.large)
      .navigationDestination(isPresented: $isChartBuilderPresented) {
        ChartBuilderStandaloneScreen()
      }
      .task {
        await handleInitialTask()
      }
      .onReceive(NotificationCenter.default.publisher(for: .portfolioDataDidChange)) { _ in
        handleHomeDataDidChange()
      }
      .onChange(of: selectedTab) { _, tab in
        handleTabSelectionChange(tab)
      }
      .onReceive(NotificationCenter.default.publisher(for: .budgetPlannerDataDidChange)) { _ in
        handleHomeDataDidChange()
      }
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button("Settings", systemImage: "gearshape") {
            openSettings()
          }
          .labelStyle(.iconOnly)
          .buttonStyle(.bordered)
          .tint(AppTheme.Colors.tint(for: colorScheme))
          .accessibilityLabel(LocalizedStringKey("Open settings"))
        }
      }
      .searchable(
        text: $searchViewModel.query,
        placement: .navigationBarDrawer(displayMode: .always),
        prompt: LocalizedStringKey("Search stocks, ETFs, or owned assets")
      )
      .onChange(of: searchViewModel.query) { _, _ in
        handleSearchQueryChange()
      }
      .onSubmit(of: .search) {
        handleSearchSubmit()
      }
      .sheet(isPresented: $isQuickAddPresented) {
        HomeQuickExpenseSheet { draft in
          await handleQuickExpenseSave(draft)
        }
      }
    }
  }

  private func handleInitialTask() async {
    await loadContent()
  }

  private func handleHomeDataDidChange() {
    Task {
      await loadHomeMetrics()
      await activityViewModel.loadActivities()
    }
  }

  private func handleTabSelectionChange(_ tab: HomeTab) {
    guard tab == .dashboard else { return }
    Task { await loadContent(force: true) }
  }

  private func openSettings() {
    isSettingsPresented = true
  }

  private func showPortfolioTab() {
    selectedTab = .portfolio
  }

  private func showExpensesTab() {
    selectedTab = .expenses
  }

  private func showReportsTab() {
    selectedTab = .reports
  }

  private func presentQuickAdd() {
    isQuickAddPresented = true
  }

  private func presentChartBuilder() {
    isChartBuilderPresented = true
  }

  private func handleSearchQueryChange() {
    searchViewModel.queryChanged()
  }

  private func handleSearchSubmit() {
    Task { await searchViewModel.searchNow() }
  }

  private func handleQuickExpenseSave(_ draft: HomeQuickExpenseDraft) async -> String? {
    await saveQuickExpense(draft)
  }

  private func loadContent(force: Bool = false) async {
      guard force || !hasLoadedContent else { return }
      async let metricsLoad: Void = loadHomeMetrics()
      async let insightsLoad: Void = loadInsights()
      async let activityLoad: Void = activityViewModel.loadActivities()
      async let focusPointsLoad: Void = focusPointsViewModel.load()
      async let budgetLoad: Void = budgetStore.load(force: force)
      _ = await (metricsLoad, insightsLoad, activityLoad, focusPointsLoad, budgetLoad)
      hasLoadedContent = true
  }

  private func loadHomeMetrics() async {
      let start = ContinuousClock.now
      isHomeMetricsLoading = true
      defer {
          isHomeMetricsLoading = false
          homePerformanceLogger.info(
              "Home metrics load duration_ms=\(Self.durationInMilliseconds(from: start.duration(to: .now)), privacy: .public)"
          )
      }

      do {
          async let performanceTask = stockService.fetchPortfolioPerformance()
          async let reportsTask = expensesService.getReportsOverview(from: nil, to: nil)
          let (performance, reports) = try await (performanceTask, reportsTask)

          let portfolioPoints = Self.mapPortfolioPoints(from: performance.points)
          let monthlySummaries = reports.monthlySummaries.sorted { $0.monthStart < $1.monthStart }
          let spendingPoints = Self.mapSpendingPoints(from: monthlySummaries)
          let reportPortfolioValue = reports.portfolioStatistics.totalMarketValue
          let resolvedPortfolioValue = portfolioPoints.last?.value ?? reportPortfolioValue
          let shouldUseReportPortfolioFallback = reportPortfolioValue > 0
            && (portfolioPoints.isEmpty || portfolioPoints.allSatisfy { $0.value == 0 })

          portfolioChartPoints = shouldUseReportPortfolioFallback
            ? [ChartDataPoint(date: Date(), value: reportPortfolioValue)]
            : portfolioPoints
          spendingChartPoints = spendingPoints
          portfolioTotalValue = resolvedPortfolioValue > 0 ? resolvedPortfolioValue : reportPortfolioValue
          spendingTotalValue = max(0, monthlySummaries.last?.actual ?? reports.latestMonthSummary?.actual ?? 0)
          portfolioDeltaPercent = Self.deltaPercent(from: portfolioPoints.map(\.value))
          spendingDeltaPercent = Self.deltaPercent(
              from: monthlySummaries.map { max(0, $0.actual) }
          )
      } catch {
          homePerformanceLogger.error("Home metrics load failed: \(error.localizedDescription, privacy: .public)")
      }
  }

  private func loadInsights() async {
      isInsightsLoading = true
      insightsLoadFailed = false

      do {
          dashboardInsights = try await dashboardService.getInsights()
      } catch {
          dashboardInsights = nil
          insightsLoadFailed = true
          homePerformanceLogger.error("Dashboard insights load failed: \(error.localizedDescription, privacy: .public)")
      }

      isInsightsLoading = false
  }

  private func saveQuickExpense(_ draft: HomeQuickExpenseDraft) async -> String? {
      let didSave = await budgetStore.recordExpenseAndWait(
          BudgetActivityDraft(
              title: draft.title,
              amount: draft.amount,
              pillar: draft.pillar,
              occurredOn: draft.occurredOn,
              linkedPlanItemID: nil,
              splitMode: draft.splitMode,
              userSharePercent: draft.userSharePercent
          )
      )
      guard didSave else {
          return budgetStore.errorMessage ?? "Could not save expense. Please try again."
      }
      await loadHomeMetrics()
      await activityViewModel.loadActivities()
      return nil
  }

  private static let apiDateFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.calendar = Calendar(identifier: .gregorian)
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      formatter.dateFormat = "yyyy-MM-dd"
      return formatter
  }()

  private static func mapPortfolioPoints(from points: [PerformancePoint]) -> [ChartDataPoint] {
      points.compactMap { point in
          guard let date = apiDateFormatter.date(from: point.date) else { return nil }
          return ChartDataPoint(date: date, value: max(0, point.value))
      }
  }

  private static func mapSpendingPoints(from summaries: [BudgetMonthSummaryResponse]) -> [ChartDataPoint] {
      summaries.compactMap { summary in
          guard let date = apiDateFormatter.date(from: summary.monthStart) else { return nil }
          return ChartDataPoint(date: date, value: max(0, summary.actual))
      }
  }

  private static func deltaPercent(from values: [Double]) -> Double? {
      guard values.count >= 2 else { return nil }
      let current = values[values.count - 1]
      let previous = values[values.count - 2]
      guard previous > 0 else { return nil }
      return (current - previous) / previous
  }

  private static func durationInMilliseconds(from duration: Duration) -> Double {
      let components = duration.components
      let millisecondsFromSeconds = Double(components.seconds) * 1_000
      let millisecondsFromAttoseconds = Double(components.attoseconds) / 1_000_000_000_000_000
      return millisecondsFromSeconds + millisecondsFromAttoseconds
  }
}

private struct DashboardContentSection: View {
  let portfolioTotalValue: Double
  let spendingTotalValue: Double
  let portfolioDeltaPercent: Double?
  let spendingDeltaPercent: Double?
  let portfolioChartPoints: [ChartDataPoint]
  let spendingChartPoints: [ChartDataPoint]
  let isHomeMetricsRedacted: Bool
  let isSearchResultsVisible: Bool
  let searchViewModel: AssetSearchViewModel
  let activityViewModel: ActivityViewModel
  let recentExpenses: [BudgetActivity]
  let financialHealth: DashboardFinancialHealthDTO?
  let isFinancialHealthLoading: Bool
  let financialHealthUnavailable: Bool
  let insightCards: [InsightCard]
  let focusPointsViewModel: FocusPointsViewModel
  let onPortfolioTap: () -> Void
  let onExpensesTap: () -> Void
  let onReportsTap: () -> Void
  let onChartBuilderTap: () -> Void
  let onQuickAddTap: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 20) {
      DashboardHeroCard(
        totalValue: portfolioTotalValue,
        totalSpending: spendingTotalValue,
        portfolioDeltaPercent: portfolioDeltaPercent,
        spendingDeltaPercent: spendingDeltaPercent,
        portfolioPoints: portfolioChartPoints,
        spendingPoints: spendingChartPoints,
        onPortfolioTap: onPortfolioTap,
        onExpensesTap: onExpensesTap,
        onReportsTap: onReportsTap
      )
      .redacted(reason: isHomeMetricsRedacted ? .placeholder : [])
      .appAnimation(AppMotion.state, value: isHomeMetricsRedacted)

      if isSearchResultsVisible {
        AssetSearchCard(viewModel: searchViewModel)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }

      UnifiedActivityFeed(
        viewModel: activityViewModel,
        recentExpenses: recentExpenses,
        financialHealth: financialHealth,
        isFinancialHealthLoading: isFinancialHealthLoading,
        financialHealthUnavailable: financialHealthUnavailable
      )

      MacroTeaserCard()

      ChartBuilderDashboardCard(onOpen: onChartBuilderTap)

      QuickAddEntryButton(action: onQuickAddTap)

      DisclosureGroup(LocalizedStringKey("More Insights")) {
        VStack(spacing: 20) {
          InsightsGrid(cards: insightCards)
          FocusListCard(viewModel: focusPointsViewModel)
        }
        .padding(.top, 16)
      }
      .tint(AppTheme.Colors.tint(for: colorScheme))
    }
    .appAnimation(AppMotion.structural, value: isSearchResultsVisible)
  }
}

private struct QuickAddEntryButton: View {
  @Environment(\.colorScheme) private var colorScheme
  let action: () -> Void

  var body: some View {
    Button("Add Entry", systemImage: "plus.circle.fill", action: action)
      .font(.headline)
      .frame(maxWidth: .infinity)
      .padding()
      .buttonStyle(.borderedProminent)
      .tint(AppTheme.Colors.tint(for: colorScheme))
  }
}

private struct DashboardHeroCard: View {
  let totalValue: Double
  let totalSpending: Double
  let portfolioDeltaPercent: Double?
  let spendingDeltaPercent: Double?
  let portfolioPoints: [ChartDataPoint]
  let spendingPoints: [ChartDataPoint]
  let onPortfolioTap: () -> Void
  let onExpensesTap: () -> Void
  let onReportsTap: () -> Void

  @Environment(\.colorScheme) private var colorScheme
  @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
  @State private var showingPortfolio = true

  private var appLanguage: AppLanguage {
    AppLanguage.from(appLanguageRawValue)
  }

  private var currentTitle: String {
    if showingPortfolio {
        return String(localized: "Total Wealth")
    } else {
        return String(localized: "Monthly Spending")
    }
  }

  private var currentValue: Double {
    showingPortfolio ? totalValue : totalSpending
  }

  private var currentPoints: [ChartDataPoint] {
    showingPortfolio ? portfolioPoints : spendingPoints
  }

  private var currentDeltaPercent: Double? {
    showingPortfolio ? portfolioDeltaPercent : spendingDeltaPercent
  }

  private var currentColor: Color {
    showingPortfolio ? .green : .orange
  }

  private var deltaSymbol: String {
    guard let currentDeltaPercent else { return "minus" }
    if showingPortfolio {
      return currentDeltaPercent >= 0 ? "arrow.up.right" : "arrow.down.right"
    }
    return currentDeltaPercent <= 0 ? "arrow.down.right" : "arrow.up.right"
  }

  private var deltaColor: Color {
    guard let currentDeltaPercent else { return .secondary }
    if showingPortfolio {
      return currentDeltaPercent >= 0 ? .green : .red
    }
    return currentDeltaPercent <= 0 ? .green : .red
  }

  private var deltaText: String {
    guard let currentDeltaPercent else {
        return String(localized: "No baseline for trend yet")
    }
    let sign = currentDeltaPercent > 0 ? "+" : ""
    let percent = (currentDeltaPercent * 100).formatted(.number.precision(.fractionLength(1)))
    let vsLastPeriod = String(localized: "vs last period")
    return "\(sign)\(percent)% \(vsLastPeriod)"
  }

  var body: some View {
    GlassCard(cornerRadius: 28) {
      VStack(alignment: .leading, spacing: 18) {
        Text(currentTitle)
          .typography(.small, weight: .semibold)
          .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 8) {
          Text(currentValue.currency)
            .typography(.displayNumber)
            .lineLimit(1)
            .contentTransition(.numericText(value: currentValue))
            .appAnimation(AppMotion.state, value: currentValue)

          HStack(spacing: 4) {
            Image(systemName: deltaSymbol).accessibilityHidden(true)
            Text(deltaText)
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(deltaColor)
        }

        InteractiveLineChart(data: currentPoints, color: currentColor)
          .frame(height: 140)
          .padding(.horizontal, -12)

        Picker("View", selection: $showingPortfolio) {
          Text(LocalizedStringKey("Portfolio")).tag(true)
          Text(LocalizedStringKey("Spending")).tag(false)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 220)
        .padding(.top, 4)
      }
    }
  }
}

private struct InsightsGrid: View {
  let cards: [InsightCard]

  private let columns = [
    GridItem(.flexible(), spacing: 16),
    GridItem(.flexible(), spacing: 16)
  ]

  var body: some View {
    LazyVGrid(columns: columns, spacing: 16) {
      ForEach(cards) { card in
        GlassCard(cornerRadius: 22) {
          VStack(alignment: .leading, spacing: 12) {
            Image(systemName: card.symbol)
              .accessibilityHidden(true)
              .font(.title3)
              .foregroundStyle(card.tint)

            Text(card.title)
              .typography(.small, weight: .semibold)

            Text(card.value)
              .typography(.headline, weight: .bold)

            Text(card.detail)
              .typography(.caption)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }
}

private struct FocusListCard: View {
  @Bindable var viewModel: FocusPointsViewModel
  @Environment(\.colorScheme) private var colorScheme

  private var orderedPoints: [GoalResponse] {
    viewModel.points.sorted { lhs, rhs in
      if lhs.status == rhs.status {
        return (lhs.createdAt ?? "") > (rhs.createdAt ?? "")
      }
      return lhs.status == .pending
    }
  }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 14) {
        Text("Focus this week")
          .typography(.small, weight: .semibold)

        HStack(spacing: 8) {
          TextField("Add a focus point", text: $viewModel.draftTitle)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(false)
            .submitLabel(.done)
            .onSubmit(createFocusPointFromDraft)

          Button("Add Focus Point", systemImage: viewModel.isSubmitting ? "" : "plus.circle.fill") {
            createFocusPointFromDraft()
          }
          .labelStyle(.iconOnly)
          .overlay {
            if viewModel.isSubmitting {
              ProgressView()
            }
          }
          .frame(width: 44, height: 44)
          .contentShape(.rect)
          .buttonStyle(.plain)
          .disabled(viewModel.isSubmitting || viewModel.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .modifier(FocusInputSurfaceModifier())

        if let errorMessage = viewModel.errorMessage {
          Text(errorMessage)
            .typography(.nano)
            .foregroundStyle(AppTheme.Colors.danger)
        }

        if viewModel.isLoading && orderedPoints.isEmpty {
          ProgressView("Loading focus points...")
        } else if orderedPoints.isEmpty {
          Text("No focus points yet. Add one to start tracking this week.")
            .typography(.small)
            .foregroundStyle(.secondary)
        } else {
          ForEach(orderedPoints) { item in
            Button {
              toggleStatus(for: item)
            } label: {
              HStack(alignment: .top, spacing: 10) {
                if item.statusUpdatedBy == .system {
                    Image(systemName: item.status == .completed ? "checkmark.seal.fill" : "seal").accessibilityHidden(true)
                      .foregroundStyle(item.status == .completed ? AppTheme.Colors.success : .indigo)
                } else {
                    Image(systemName: item.status == .completed ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
                      .foregroundStyle(item.status == .completed ? AppTheme.Colors.success : .secondary)
                }

                Text(item.title)
                  .typography(.small)
                  .strikethrough(item.status == .completed && item.statusUpdatedBy != .system)
                  .foregroundStyle(item.status == .completed ? .secondary : .primary)
                  .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.pendingStatusUpdates.contains(item.id) {
                  ProgressView()
                    .controlSize(.small)
                }
              }
              .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(item.statusUpdatedBy == .system && item.status == .completed)
          }
        }
      }
    }
  }

  private func createFocusPointFromDraft() {
    Task { await viewModel.createFromDraft() }
  }

  private func toggleStatus(for item: GoalResponse) {
    guard item.statusUpdatedBy != .system else { return }
    Task { await viewModel.toggleStatus(for: item) }
  }
}

private struct AssetSearchCard: View {
  var viewModel: AssetSearchViewModel
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 12) {
        Text("Search results")
          .typography(.small, weight: .semibold)

        if viewModel.isLoading {
          ProgressView("Searching...")
        } else if let errorMessage = viewModel.errorMessage {
          Text(errorMessage)
            .typography(.small)
            .foregroundStyle(AppTheme.Colors.danger)
        } else if viewModel.results.isEmpty {
          Text("No assets found for this query.")
            .typography(.small)
            .foregroundStyle(.secondary)
        } else {
          ForEach(viewModel.results) { result in
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Text(result.symbol)
                  .typography(.label, weight: .semibold)
                Spacer()
                if let exchange = result.exchange {
                  Text(exchange)
                    .typography(.caption)
                    .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                }
              }

              Text(result.name)
                .typography(.small)
                .foregroundStyle(.secondary)
            }

            if result.id != viewModel.results.last?.id {
              Divider()
            }
          }
        }
      }
    }
  }
}

private struct FocusInputSurfaceModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .appGlassEffect(.rect(cornerRadius: 12))
  }
}

struct InsightCard: Identifiable {
  let title: String
  let value: String
  let detail: String
  let symbol: String
  let tint: Color


  var id: String { title }
}
