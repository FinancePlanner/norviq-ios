import Charts
import Foundation
import Observation
import OSLog
import StoreKit
import SwiftUI
import StockPlanShared
import Factory

private let homePerformanceLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
  category: "HomePerformance"
)

@MainActor
@Observable
final class ActivityViewModel {
    var activities: [UserActivityResponse] = []
    var isLoading = false
    var errorMessage: String?

    @ObservationIgnored
    @Injected(\.activityService) private var activityService

    func loadActivities() async {
        let start = ContinuousClock.now
        isLoading = true
        errorMessage = nil
        do {
            activities = try await activityService.fetchActivities(limit: 5)
        } catch {
            homePerformanceLogger.error("Activity feed load failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
        homePerformanceLogger.debug(
            "Activity feed load duration_ms=\(Self.durationInMilliseconds(from: start.duration(to: .now)), privacy: .public)"
        )
    }

    private static func durationInMilliseconds(from duration: Duration) -> Double {
        let components = duration.components
        let millisecondsFromSeconds = Double(components.seconds) * 1_000
        let millisecondsFromAttoseconds = Double(components.attoseconds) / 1_000_000_000_000_000
        return millisecondsFromSeconds + millisecondsFromAttoseconds
    }
}

@MainActor
@Observable
final class FocusPointsViewModel {
    var points: [GoalResponse] = []
    var draftTitle = ""
    var isLoading = false
    var isSubmitting = false
    var pendingStatusUpdates: Set<String> = []
    var errorMessage: String?

    @ObservationIgnored
    @Injected(\.goalsService) private var goalsService

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            points = try await goalsService.getGoals()
        } catch {
            homePerformanceLogger.error("Focus points load failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    func createFromDraft() async {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !isSubmitting else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let created = try await goalsService.createGoal(payload: GoalRequest(title: title))
            points.insert(created, at: 0)
            draftTitle = ""
        } catch {
            homePerformanceLogger.error("Focus point create failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    func toggleStatus(for point: GoalResponse) async {
        guard !pendingStatusUpdates.contains(point.id) else { return }
        pendingStatusUpdates.insert(point.id)
        errorMessage = nil
        defer { pendingStatusUpdates.remove(point.id) }

        let nextStatus: GoalStatus = point.status == .completed ? .pending : .completed
        do {
            let updated = try await goalsService.updateGoalStatus(
                id: point.id,
                payload: GoalStatusUpdateRequest(status: nextStatus, source: .manual)
            )

            guard let index = points.firstIndex(where: { $0.id == updated.id }) else { return }
            points[index] = updated
        } catch {
            homePerformanceLogger.error("Focus point status update failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }
}

private enum HomeTab: Hashable {
  case dashboard
  case portfolio
  case expenses
  case reports

  func title(language: AppLanguage) -> String {
    switch self {
    case .dashboard:
      language.localized(english: "Home", portuguese: "Início")
    case .portfolio:
      language.localized(english: "Portfolio", portuguese: "Portefólio")
    case .expenses:
      language.localized(english: "Expenses", portuguese: "Despesas")
    case .reports:
      language.localized(english: "Reports", portuguese: "Relatórios")
    }
  }
}

private enum PortfolioSegment: String, CaseIterable, Identifiable {
  case holdings
  case allocation
  case watchlist
  case earnings
  case news

  var id: String { rawValue }

  var isProOnly: Bool {
    switch self {
    case .allocation, .earnings, .news:
      return true
    case .holdings, .watchlist:
      return false
    }
  }

  func title(language: AppLanguage) -> String {
    switch self {
    case .holdings:
      return language.localized(english: "Holdings", portuguese: "Posições")
    case .allocation:
      return language.localized(english: "Allocation", portuguese: "Alocação")
    case .watchlist:
      return language.localized(english: "Watchlist", portuguese: "Lista de seguimento")
    case .earnings:
      return language.localized(english: "Earnings", portuguese: "Resultados")
    case .news:
      return language.localized(english: "News", portuguese: "Notícias")
    }
  }
}

@MainActor
struct HomeScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @InjectedObservable(\Container.billingManager) private var billingManager
  @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
  let onLogout: () async -> Void
  @State private var selectedTab: HomeTab = .dashboard
  @State private var isSettingsPresented = false
  @State private var isPaywallPresented = false
  @State private var pendingPortfolioOpenSymbol: String?
  @StateObject private var budgetPlannerViewModel = BudgetPlannerViewModel()

  private var appLanguage: AppLanguage {
    AppLanguage.from(appLanguageRawValue)
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      DashboardRoot(
        selectedTab: $selectedTab,
        isSettingsPresented: $isSettingsPresented,
        budgetStore: budgetPlannerViewModel
      )
        .tabItem {
          tabLabel(.dashboard, systemImage: "house")
        }
        .tag(HomeTab.dashboard)

      PortfolioRoot(
        isSettingsPresented: $isSettingsPresented,
        pendingOpenSymbol: $pendingPortfolioOpenSymbol
      )
        .tabItem {
          tabLabel(.portfolio, systemImage: "chart.line.uptrend.xyaxis")
        }
        .tag(HomeTab.portfolio)

      ExpensesPlannerScreen(isSettingsPresented: $isSettingsPresented, viewModel: budgetPlannerViewModel)
        .accessibilityIdentifier("tab.expenses")
        .tabItem {
          tabLabel(.expenses, systemImage: "creditcard")
        }
        .tag(HomeTab.expenses)

      ExpensesComparisonScreen()
        .accessibilityIdentifier("tab.reports")
        .tabItem {
          tabLabel(.reports, systemImage: "chart.bar.xaxis")
        }
        .tag(HomeTab.reports)
    }
    .id(appLanguage.rawValue)
    .tint(AppTheme.Colors.tint(for: colorScheme))
    .toolbarBackground(.visible, for: .tabBar)
    .toolbarBackground(AppTheme.Colors.tabBarBackground(for: colorScheme), for: .tabBar)
    .animation(.snappy(duration: 0.28), value: selectedTab)
    .sheet(isPresented: $isSettingsPresented) {
      settingsSheet
    }
    .sheet(isPresented: $isPaywallPresented) {
      PaywallView(billingManager: billingManager)
    }
    .onChange(of: selectedTab) { _, newValue in
      guard newValue == .reports, !billingManager.isPro else { return }
      selectedTab = .dashboard
      isPaywallPresented = true
    }
    .onReceive(NotificationCenter.default.publisher(for: .openStockFromPushNotification)) { notification in
      handleOpenStockNotification(notification)
    }
    .onReceive(NotificationCenter.default.publisher(for: .openPortfolioFromPushNotification)) { _ in
      openPortfolioTab()
    }
  }

  private func tabLabel(_ tab: HomeTab, systemImage: String) -> some View {
    Label {
      Text(tab.title(language: appLanguage))
    } icon: {
      Image(systemName: systemImage)
    }
  }

  private var settingsSheet: some View {
    UserProfileView()
      .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
  }

  private func handleOpenStockNotification(_ notification: Notification) {
    guard
      let symbol = notification.userInfo?["symbol"] as? String,
      !symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return
    }

    pendingPortfolioOpenSymbol = symbol
    selectedTab = .portfolio
  }

  private func openPortfolioTab() {
    pendingPortfolioOpenSymbol = nil
    selectedTab = .portfolio
  }
}

@MainActor
private struct DashboardRoot: View {
  @Environment(\.colorScheme) private var colorScheme
  @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
  @Binding var selectedTab: HomeTab
  @Binding var isSettingsPresented: Bool
  @ObservedObject var budgetStore: BudgetPlannerViewModel
  @StateObject private var searchViewModel = AssetSearchViewModel()
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
            title: appLanguage.localized(english: "Savings rate", portuguese: "Taxa de poupança"),
            value: "\(Int(insights.savingsRate))%",
            detail: appLanguage.localized(english: "Based on monthly planned vs actuals.", portuguese: "Baseado no planeado vs real mensal."),
            symbol: "arrow.down.circle",
            tint: AppTheme.Colors.success
        ),
        .init(
            title: appLanguage.localized(english: "Budget streak", portuguese: "Série de orçamento"),
            value: appLanguage.localized(english: "\(insights.budgetStreak) months", portuguese: "\(insights.budgetStreak) meses"),
            detail: appLanguage.localized(english: "Staying under your spending plan.", portuguese: "Mantendo-se abaixo do seu plano de gastos."),
            symbol: "flame",
            tint: .orange
        ),
        .init(
            title: appLanguage.localized(english: "Watchlist", portuguese: "Seguimento"),
            value: appLanguage.localized(english: "\(insights.watchlistCount) names", portuguese: "\(insights.watchlistCount) ativos"),
            detail: appLanguage.localized(english: "Review candidates before earnings.", portuguese: "Analise candidatos antes dos resultados."),
            symbol: "star",
            tint: .indigo
        ),
        .init(
            title: appLanguage.localized(english: "Cash buffer", portuguese: "Reserva de caixa"),
            value: insights.cashBuffer.formatted(.currency(code: "USD").presentation(.narrow)),
            detail: appLanguage.localized(english: "Enough for short-term volatility.", portuguese: "Suficiente para volatilidade de curto prazo."),
            symbol: "shield",
            tint: AppTheme.Colors.tint(for: .light)
        )
    ]
  }

  private var greetingText: String {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 5..<12: return appLanguage.localized(english: "Good morning", portuguese: "Bom dia")
    case 12..<17: return appLanguage.localized(english: "Good afternoon", portuguese: "Boa tarde")
    case 17..<22: return appLanguage.localized(english: "Good evening", portuguese: "Boa noite")
    default: return appLanguage.localized(english: "Good night", portuguese: "Boa noite")
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
          if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 20) {
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
                onQuickAddTap: presentQuickAdd
              )
            }
          } else {
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
              onQuickAddTap: presentQuickAdd
            )
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
      }
      .background(MeshGradientBackground())
      .navigationTitle(greetingText)
      .navigationBarTitleDisplayMode(.large)
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
          if #available(iOS 26, *) {
            Button(action: openSettings) {
              Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.glass)
            .tint(AppTheme.Colors.tint(for: colorScheme))
            .accessibilityLabel(LocalizedStringKey("Open settings"))
          } else {
            Button(action: openSettings) {
              Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
                .padding(6)
                .appGlassEffect(.capsule)
            }
            .accessibilityLabel(LocalizedStringKey("Open settings"))
          }
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
  let onQuickAddTap: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
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
}

private struct QuickAddEntryButton: View {
  @Environment(\.colorScheme) private var colorScheme
  let action: () -> Void

  var body: some View {
    if #available(iOS 26, *) {
      Button(action: action) {
        Label(LocalizedStringKey("Add Entry"), systemImage: "plus.circle.fill")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding()
      }
      .buttonStyle(.glassProminent)
      .tint(AppTheme.Colors.tint(for: colorScheme))
    } else {
      Button(action: action) {
        HStack {
          Image(systemName: "plus.circle.fill")
          Text(LocalizedStringKey("Add Entry"))
            .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.1))
        .clipShape(.rect(cornerRadius: 16))
        .foregroundStyle(.white)
      }
    }
  }
}

private struct PortfolioRoot: View {
  @Binding var isSettingsPresented: Bool
  @Binding var pendingOpenSymbol: String?
  @Environment(\.colorScheme) private var colorScheme
  @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
  @StateObject private var portfolioViewModel = PortfolioViewModel()
  @StateObject private var watchlistViewModel = WatchlistViewModel()
  @State private var selectedSegment: PortfolioSegment = .holdings
  @State private var isListManagerPresented = false
  @State private var isPaywallPresented = false
  @InjectedObservable(\Container.billingManager) private var billingManager

  private var appLanguage: AppLanguage {
    AppLanguage.from(appLanguageRawValue)
  }

  private var shouldShowListSwitcher: Bool {
    selectedSegment == .holdings || selectedSegment == .watchlist
  }

  private var portfolioListItems: [ListSwitcherItem] {
    [.init(id: "__all__", name: "All", isDefault: false)]
      + portfolioViewModel.portfolioLists.map {
        .init(id: $0.id, name: $0.name, isDefault: $0.isDefault)
      }
  }

  private var watchlistItems: [ListSwitcherItem] {
    watchlistViewModel.watchlistLists.map {
      .init(id: $0.id, name: $0.name, isDefault: $0.isDefault)
    }
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        segmentPicker

        if shouldShowListSwitcher {
          listSwitcher
            .padding(.horizontal, 16)
        }

        segmentContent
        .animation(.snappy(duration: 0.24), value: selectedSegment)
      }
      .environmentObject(portfolioViewModel)
      .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
      .navigationTitle(LocalizedStringKey("Portfolio"))
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button(action: openSettings) {
            Image(systemName: "gearshape")
              .font(.system(size: 16, weight: .semibold))
          }
          .buttonStyle(.glass)
          .tint(AppTheme.Colors.tint(for: colorScheme))
          .accessibilityLabel("Open settings")
        }
      }
      .onChange(of: pendingOpenSymbol) { _, symbol in
        handlePendingOpenSymbolChange(symbol)
      }
      .onReceive(NotificationCenter.default.publisher(for: .openPortfolioFromPushNotification)) { _ in
        showHoldingsSegment()
      }
      .sheet(isPresented: $isListManagerPresented) {
        listManagerSheet
      }
      .task {
        await loadLists()
      }
      .sheet(isPresented: $isPaywallPresented) {
        PaywallView(billingManager: billingManager)
      }
      .onChange(of: selectedSegment) { _, value in
        handleSegmentChange(value)
      }
    }
  }

  private var segmentPicker: some View {
    GlassEffectContainer(spacing: 8) {
      Picker("Portfolio section", selection: $selectedSegment) {
        ForEach(PortfolioSegment.allCases) { segment in
          let title = segment.title(language: appLanguage)
          Text(!billingManager.isPro && segment.isProOnly ? "\(title) 🔒" : title).tag(segment)
        }
      }
      .pickerStyle(.segmented)
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
  }

  @ViewBuilder
  private var listSwitcher: some View {
    if selectedSegment == .holdings {
      PortfolioListSwitcherBar(
        items: portfolioListItems,
        selectedId: portfolioViewModel.isShowingAllLists ? "__all__" : portfolioViewModel.selectedPortfolioListId,
        onSelect: selectPortfolioList,
        onManage: presentListManager
      )
    } else {
      PortfolioListSwitcherBar(
        items: watchlistItems,
        selectedId: watchlistViewModel.selectedWatchlistListId,
        onSelect: selectWatchlistList,
        onManage: presentListManager
      )
    }
  }

  @ViewBuilder
  private var segmentContent: some View {
    switch selectedSegment {
    case .holdings:
      PortfolioScreen(pendingOpenSymbol: $pendingOpenSymbol)
    case .allocation:
      PortfolioAllocationScreen()
    case .watchlist:
      WatchlistTab(viewModel: watchlistViewModel)
    case .earnings:
      EarningsCalendarScreen()
    case .news:
      MarketNewsScreen()
    }
  }

  @ViewBuilder
  private var listManagerSheet: some View {
    if selectedSegment == .holdings {
      PortfolioListManagementSheet(
        title: "Manage Portfolios",
        lists: portfolioViewModel.portfolioLists,
        onCreate: createPortfolioList,
        onRename: renamePortfolioList,
        onDelete: deletePortfolioList
      )
    } else {
      WatchlistListManagementSheet(
        title: "Manage Watchlists",
        lists: watchlistViewModel.watchlistLists,
        onCreate: createWatchlistList,
        onRename: renameWatchlistList,
        onDelete: deleteWatchlistList
      )
    }
  }

  private func openSettings() {
    isSettingsPresented = true
  }

  private func presentListManager() {
    isListManagerPresented = true
  }

  private func handlePendingOpenSymbolChange(_ symbol: String?) {
    guard
      let symbol = symbol?.trimmingCharacters(in: .whitespacesAndNewlines),
      !symbol.isEmpty
    else {
      return
    }

    selectedSegment = .holdings
  }

  private func showHoldingsSegment() {
    selectedSegment = .holdings
  }

  private func loadLists() async {
    await portfolioViewModel.load(force: true)
    await watchlistViewModel.load(force: true)
  }

  private func handleSegmentChange(_ value: PortfolioSegment) {
    if value.isProOnly && !billingManager.isPro {
      // Revert selection and show paywall
      selectedSegment = .holdings
      isPaywallPresented = true
      return
    }

    switch value {
    case .holdings:
      Task { await portfolioViewModel.load(force: true) }
    case .watchlist:
      Task { await watchlistViewModel.load(force: true) }
    case .allocation, .earnings, .news:
      break
    }
  }

  private func selectPortfolioList(_ id: String) {
    Task {
      if id == "__all__" {
        await portfolioViewModel.selectAllLists()
      } else {
        await portfolioViewModel.selectPortfolioList(id)
      }
    }
  }

  private func selectWatchlistList(_ id: String) {
    Task { await watchlistViewModel.selectWatchlistList(id) }
  }

  private func createPortfolioList(name: String) async -> String? {
    await portfolioViewModel.createPortfolioList(name: name)
  }

  private func renamePortfolioList(id: String, name: String) async -> String? {
    await portfolioViewModel.renamePortfolioList(id: id, name: name)
  }

  private func deletePortfolioList(id: String) async -> String? {
    await portfolioViewModel.deletePortfolioList(id: id)
  }

  private func createWatchlistList(name: String) async -> String? {
    await watchlistViewModel.createWatchlistList(name: name)
  }

  private func renameWatchlistList(id: String, name: String) async -> String? {
    await watchlistViewModel.renameWatchlistList(id: id, name: name)
  }

  private func deleteWatchlistList(id: String) async -> String? {
    await watchlistViewModel.deleteWatchlistList(id: id)
  }
}

private struct ListSwitcherItem: Identifiable {
  let id: String
  let name: String
  let isDefault: Bool
}

private struct PortfolioListSwitcherBar: View {
  @Environment(\.colorScheme) private var colorScheme
  let items: [ListSwitcherItem]
  let selectedId: String?
  let onSelect: (String) -> Void
  let onManage: () -> Void

  var body: some View {
    GlassEffectContainer(spacing: 12) {
      HStack(spacing: 0) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(items) { item in
              listChip(item)
            }
          }
          .padding(.vertical, 4)
          .padding(.leading, 2)
          .padding(.trailing, 8)
        }

        Divider()
          .frame(height: 24)
          .padding(.horizontal, 4)

        manageButton
      }
    }
  }

  @ViewBuilder
  private func listChip(_ item: ListSwitcherItem) -> some View {
    let isSelected = selectedId == item.id

    if #available(iOS 26, *) {
      Button(action: { onSelect(item.id) }) {
        HStack(spacing: 5) {
          if item.isDefault {
            Image(systemName: "star.fill")
              .font(.system(size: 9, weight: .bold))
          }
          Text(item.name)
            .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
      }
      .foregroundStyle(isSelected ? Color.white : Color.primary)
      .accessibilityLabel(Text(item.name))
      .glassEffect(
        isSelected
          ? .regular.tint(AppTheme.Colors.tint(for: colorScheme)).interactive()
          : .regular.interactive(),
        in: .capsule
      )
    } else {
      Button(action: { onSelect(item.id) }) {
        HStack(spacing: 5) {
          if item.isDefault {
            Image(systemName: "star.fill")
              .font(.system(size: 9, weight: .bold))
          }
          Text(item.name)
            .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
      }
      .foregroundStyle(isSelected ? Color.white : Color.primary)
      .accessibilityLabel(Text(item.name))
      .background(
        Capsule()
          .fill(
            isSelected
              ? AppTheme.Colors.tint(for: colorScheme)
              : AppTheme.Colors.tertiaryFill(for: colorScheme)
          )
      )
      .overlay(
        Capsule()
          .strokeBorder(AppTheme.Colors.separator(for: colorScheme))
      )
    }
  }

  @ViewBuilder
  private var manageButton: some View {
    if #available(iOS 26, *) {
      Button(action: onManage) {
        Image(systemName: "slider.horizontal.3")
          .font(.subheadline.weight(.semibold))
      }
      .buttonStyle(.glass)
      .controlSize(.small)
      .accessibilityLabel("Manage lists")
    } else {
      Button(action: onManage) {
        Image(systemName: "slider.horizontal.3")
          .font(.subheadline.weight(.semibold))
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .accessibilityLabel("Manage lists")
    }
  }
}

// MARK: - Unified List Management Sheet

private struct ListManagementItem: Identifiable {
  let id: String
  let name: String
  let isDefault: Bool
}

/// Generic management sheet shared by both portfolio lists and watchlist lists.
private struct ListManagementSheet: View {
  let title: String
  let placeholder: String
  let items: [ListManagementItem]
  let onCreate: (String) async -> String?
  let onRename: (String, String) async -> String?
  let onDelete: (String) async -> String?

  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme

  @State private var newName = ""
  @State private var editingId: String? = nil
  @State private var draftName = ""
  @State private var pendingDeleteItem: ListManagementItem? = nil
  @State private var isCreating = false

  // Toast
  @State private var toastMessage: String? = nil
  @State private var toastStyle: ToastBanner.Style = .success

  private var isNewNameValid: Bool {
    !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var deleteDialogTitle: String {
    if let name = pendingDeleteItem?.name {
      return "Delete \(name)?"
    }
    return "Delete this list?"
  }

  var body: some View {
    NavigationStack {
      List {
        createSection
        existingSection
      }
      .listStyle(.insetGrouped)
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
            .fontWeight(.semibold)
        }
      }
      // Delete confirmation
      .confirmationDialog(
        deleteDialogTitle,
        isPresented: Binding(
          get: { pendingDeleteItem != nil },
          set: { if !$0 { pendingDeleteItem = nil } }
        ),
        titleVisibility: .visible
      ) {
        if let item = pendingDeleteItem {
          Button("Delete", role: .destructive) {
            performDelete(item)
          }
          Button("Cancel", role: .cancel) { pendingDeleteItem = nil }
        }
      } message: {
        Text("This list and all its contents will be removed. This cannot be undone.")
      }
      // Toast overlay
      .overlay(alignment: .top) {
        if let message = toastMessage {
          ToastBanner(message: message, style: toastStyle)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
      .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toastMessage)
    }
  }

  // MARK: - Create Section

  private var createSection: some View {
    Section {
      HStack(spacing: 10) {
        Image(systemName: "plus.circle.fill")
          .foregroundStyle(isNewNameValid ? AppTheme.Colors.tint(for: colorScheme) : .secondary)
          .animation(.easeInOut(duration: 0.2), value: isNewNameValid)

        TextField(placeholder, text: $newName)
          .submitLabel(.done)
          .onSubmit { createList() }

        if isCreating {
          ProgressView()
            .controlSize(.small)
        } else {
          Button {
            createList()
          } label: {
            Image(systemName: "arrow.up.circle.fill")
              .font(.title3)
              .foregroundStyle(isNewNameValid
                ? AppTheme.Colors.tint(for: colorScheme)
                : Color.secondary.opacity(0.4)
              )
          }
          .buttonStyle(.plain)
          .disabled(!isNewNameValid)
          .animation(.easeInOut(duration: 0.2), value: isNewNameValid)
        }
      }
    } header: {
      Text("New List")
    } footer: {
      Text("Enter a name then tap ↑ or press Return.")
    }
  }

  // MARK: - Existing Section

  @ViewBuilder
  private var existingSection: some View {
    if !items.isEmpty {
      Section {
        ForEach(items) { item in
          itemRow(item)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              if !item.isDefault {
                Button(role: .destructive) {
                  pendingDeleteItem = item
                } label: {
                  Label("Delete", systemImage: "trash")
                }
              }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
              Button {
                beginEditing(item)
              } label: {
                Label("Rename", systemImage: "pencil")
              }
              .tint(.indigo)
            }
        }
      } header: {
        HStack {
          Text("Your Lists")
          Spacer()
          Text("\(items.count)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
      } footer: {
        Text("Swipe left to delete, right to rename. Default lists cannot be deleted.")
      }
    }
  }

  @ViewBuilder
  private func itemRow(_ item: ListManagementItem) -> some View {
    if editingId == item.id {
      // Inline editing mode
      HStack(spacing: 10) {
        Image(systemName: "pencil.circle.fill")
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))

        TextField("List name", text: $draftName)
          .submitLabel(.done)
          .onSubmit { commitRename(item) }

        Button {
          commitRename(item)
        } label: {
          Image(systemName: "checkmark.circle.fill")
            .font(.title3)
            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
        }
        .buttonStyle(.plain)

        Button {
          editingId = nil
          draftName = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
    } else {
      // Display mode
      HStack(spacing: 10) {
        if item.isDefault {
          Image(systemName: "star.fill")
            .font(.caption)
            .foregroundStyle(.yellow)
        }
        Text(item.name)
          .font(.body)

        Spacer()

        if item.isDefault {
          Text("Default")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.12), in: Capsule())
        }
      }
      .contentShape(Rectangle())
      .onTapGesture { beginEditing(item) }
    }
  }

  // MARK: - Actions

  private func createList() {
    guard isNewNameValid else { return }
    let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    isCreating = true
    Task {
      let error = await onCreate(name)
      isCreating = false
      if let error {
        showToast(error, style: .error)
      } else {
        newName = ""
        showToast("\"\(name)\" created", style: .success)
      }
    }
  }

  private func beginEditing(_ item: ListManagementItem) {
    editingId = item.id
    draftName = item.name
  }

  private func commitRename(_ item: ListManagementItem) {
    let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != item.name else {
      editingId = nil
      return
    }
    Task {
      let error = await onRename(item.id, trimmed)
      editingId = nil
      draftName = ""
      if let error {
        showToast(error, style: .error)
      } else {
        showToast("Renamed to \"\(trimmed)\"", style: .success)
      }
    }
  }

  private func performDelete(_ item: ListManagementItem) {
    pendingDeleteItem = nil
    Task {
      let error = await onDelete(item.id)
      if let error {
        showToast(error, style: .error)
      } else {
        showToast("\"\(item.name)\" deleted", style: .success)
      }
    }
  }

  private func showToast(_ message: String, style: ToastBanner.Style) {
    toastMessage = message
    toastStyle = style
    Task {
      try? await Task.sleep(for: .seconds(2.5))
      withAnimation {
        if toastMessage == message { toastMessage = nil }
      }
    }
  }
}

// MARK: - Convenience wrappers preserving call sites

private struct PortfolioListManagementSheet: View {
  let title: String
  let lists: [PortfolioListDTOResponse]
  let onCreate: (String) async -> String?
  let onRename: (String, String) async -> String?
  let onDelete: (String) async -> String?

  var body: some View {
    ListManagementSheet(
      title: title,
      placeholder: "Portfolio name",
      items: lists.map { .init(id: $0.id, name: $0.name, isDefault: $0.isDefault) },
      onCreate: onCreate,
      onRename: onRename,
      onDelete: onDelete
    )
  }
}

private struct WatchlistListManagementSheet: View {
  let title: String
  let lists: [WatchlistListDTOResponse]
  let onCreate: (String) async -> String?
  let onRename: (String, String) async -> String?
  let onDelete: (String) async -> String?

  var body: some View {
    ListManagementSheet(
      title: title,
      placeholder: "Watchlist name",
      items: lists.map { .init(id: $0.id, name: $0.name, isDefault: $0.isDefault) },
      onCreate: onCreate,
      onRename: onRename,
      onDelete: onDelete
    )
  }
}

// MARK: - Dashboard cards

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
        return appLanguage.localized(english: "Total Wealth", portuguese: "Riqueza Total")
    } else {
        return appLanguage.localized(english: "Monthly Spending", portuguese: "Gastos Mensais")
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
        return appLanguage.localized(english: "No baseline for trend yet", portuguese: "Sem dados para tendência ainda")
    }
    let sign = currentDeltaPercent > 0 ? "+" : ""
    let percent = (currentDeltaPercent * 100).formatted(.number.precision(.fractionLength(1)))
    let vsLastPeriod = appLanguage.localized(english: "vs last period", portuguese: "vs período anterior")
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
            .typography(.display, weight: .bold)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .contentTransition(.numericText())

          HStack(spacing: 4) {
            Image(systemName: deltaSymbol)
            Text(deltaText)
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(deltaColor)
        }

        InteractiveLineChart(data: currentPoints, color: currentColor)
          .frame(height: 140)
          .padding(.horizontal, -12)

        HStack {
            Spacer()
            // Custom segmented picker to look like standard Apple toggle
            HStack(spacing: 0) {
                Text(appLanguage.localized(english: "Portfolio", portuguese: "Portefólio"))
                    .font(.subheadline)
                    .foregroundStyle(showingPortfolio ? .primary : .secondary)
                    .padding(.trailing, 8)

                Toggle("", isOn: $showingPortfolio)
                    .labelsHidden()
                    .tint(.white.opacity(0.8))

                Text(appLanguage.localized(english: "Spending", portuguese: "Gastos"))
                    .font(.subheadline)
                    .foregroundStyle(!showingPortfolio ? .primary : .secondary)
                    .padding(.leading, 8)
            }
            Spacer()
        }
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

          Button(action: createFocusPointFromDraft) {
            if viewModel.isSubmitting {
              ProgressView()
            } else {
              Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
            }
          }
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
                    Image(systemName: item.status == .completed ? "checkmark.seal.fill" : "seal")
                      .foregroundStyle(item.status == .completed ? AppTheme.Colors.success : .indigo)
                } else {
                    Image(systemName: item.status == .completed ? "checkmark.circle.fill" : "circle")
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
  @ObservedObject var viewModel: AssetSearchViewModel
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

// MARK: - Shared small views

private struct DashboardActionButton: View {
  let title: String
  let symbol: String
  let tint: Color
  var isDisabled: Bool = false
  let action: () -> Void

  var body: some View {
    Group {
      if #available(iOS 26, *) {
        Button(action: action) {
          actionContent
            .padding(.vertical, 12)
        }
        .buttonStyle(.glass)
        .tint(tint)
        .opacity(isDisabled ? 0.6 : 1.0)
        .disabled(isDisabled)
      } else {
        Button(action: action) {
          actionContent
            .padding(.vertical, 12)
            .appGlassEffect(.rect(cornerRadius: 18), tint: tint.opacity(0.10))
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
      }
    }
  }

  private var actionContent: some View {
    VStack(spacing: 8) {
      Image(systemName: symbol)
        .font(.headline.weight(.semibold))
        .foregroundStyle(isDisabled ? .secondary.opacity(0.8) : tint)

      HStack(spacing: 4) {
        Text(title)
          .typography(.nano, weight: .semibold)
          .foregroundStyle(isDisabled ? .secondary : tint)

        if isDisabled {
          Text("Soon")
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.red, in: Capsule())
        }
      }
    }
    .frame(maxWidth: .infinity)
  }
}

private struct FocusInputSurfaceModifier: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26, *) {
      content
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    } else {
      content
        .appGlassEffect(.rect(cornerRadius: 12))
    }
  }
}

// MARK: - Models

private struct PortfolioTrendPoint: Identifiable {
  let label: String
  let value: Double

  var id: String { label }

#if DEBUG
  static let mock: [PortfolioTrendPoint] = [
    .init(label: "Mon", value: 112_300),
    .init(label: "Tue", value: 113_840),
    .init(label: "Wed", value: 113_120),
    .init(label: "Thu", value: 114_680),
    .init(label: "Fri", value: 116_020),
    .init(label: "Sat", value: 118_920),
    .init(label: "Sun", value: 124_830)
  ]
#endif
}

private struct SpendingPoint: Identifiable {
  let label: String
  let value: Double

  var id: String { label }

#if DEBUG
  static let mock: [SpendingPoint] = [
    .init(label: "Jan", value: 980),
    .init(label: "Feb", value: 860),
    .init(label: "Mar", value: 780),
    .init(label: "Apr", value: 910)
  ]
#endif
}

private struct InsightCard: Identifiable {
  let title: String
  let value: String
  let detail: String
  let symbol: String
  let tint: Color

  var id: String { title }

#if DEBUG
  static func mock(language: AppLanguage) -> [InsightCard] {
    [
      .init(
        title: language.localized(english: "Savings rate", portuguese: "Taxa de poupança"),
        value: "28%",
        detail: language.localized(english: "Holding steady over the last quarter.", portuguese: "Mantendo-se estável no último trimestre."),
        symbol: "arrow.down.circle",
        tint: AppTheme.Colors.success
      ),
      .init(
        title: language.localized(english: "Budget streak", portuguese: "Série de orçamento"),
        value: language.localized(english: "4 months", portuguese: "4 meses"),
        detail: language.localized(english: "Staying under your spending plan.", portuguese: "Mantendo-se abaixo do seu plano de gastos."),
        symbol: "flame",
        tint: .orange
      ),
      .init(
        title: language.localized(english: "Watchlist", portuguese: "Seguimento"),
        value: language.localized(english: "12 names", portuguese: "12 ativos"),
        detail: language.localized(english: "Review candidates before earnings.", portuguese: "Analise candidatos antes dos resultados."),
        symbol: "star",
        tint: .indigo
      ),
      .init(
        title: language.localized(english: "Cash buffer", portuguese: "Reserva de caixa"),
        value: "$9.4K",
        detail: language.localized(english: "Enough for short-term volatility.", portuguese: "Suficiente para volatilidade de curto prazo."),
        symbol: "shield",
        tint: AppTheme.Colors.tint(for: .light)
      )
    ]
  }
#endif
}
