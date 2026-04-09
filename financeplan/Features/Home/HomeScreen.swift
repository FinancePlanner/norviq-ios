import Charts
import Combine
import Foundation
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
final class ActivityViewModel: ObservableObject {
    @Published var activities: [UserActivityResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

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
final class FocusPointsViewModel: ObservableObject {
    @Published var points: [GoalResponse] = []
    @Published var draftTitle = ""
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var pendingStatusUpdates: Set<String> = []
    @Published var errorMessage: String?

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
}

private enum PortfolioSegment: String, CaseIterable, Identifiable {
  case holdings
  case allocation
  case watchlist
  case earnings
  case news

  var id: String { rawValue }

  var title: String {
    switch self {
    case .holdings:
      "Holdings"
    case .allocation:
      "Allocation"
    case .watchlist:
      "Watchlist"
    case .earnings:
      "Earnings"
    case .news:
      "News"
    }
  }
}

@MainActor
struct HomeScreen: View {
  let onLogout: () async -> Void

  @Environment(\.colorScheme) private var colorScheme
  @State private var selectedTab: HomeTab = .dashboard
  @State private var isSettingsPresented = false
  @StateObject private var budgetPlannerViewModel = BudgetPlannerViewModel()

  var body: some View {
    TabView(selection: $selectedTab) {
      DashboardRoot(
        selectedTab: $selectedTab,
        isSettingsPresented: $isSettingsPresented,
        budgetStore: budgetPlannerViewModel
      )
        .tabItem {
          Label("Home", systemImage: "house")
        }
        .tag(HomeTab.dashboard)

      PortfolioRoot(isSettingsPresented: $isSettingsPresented)
        .tabItem {
          Label("Portfolio", systemImage: "chart.line.uptrend.xyaxis")
        }
        .tag(HomeTab.portfolio)

      ExpensesPlannerScreen(isSettingsPresented: $isSettingsPresented, viewModel: budgetPlannerViewModel)
        .tabItem {
          Label("Expenses", systemImage: "creditcard")
        }
        .tag(HomeTab.expenses)

      ExpensesComparisonScreen()
        .tabItem {
          Label("Reports", systemImage: "chart.bar.xaxis")
        }
        .tag(HomeTab.reports)
    }
    .tint(AppTheme.Colors.tint(for: colorScheme))
    .toolbarBackground(.visible, for: .tabBar)
    .toolbarBackground(AppTheme.Colors.tabBarBackground(for: colorScheme), for: .tabBar)
    .animation(.snappy(duration: 0.28), value: selectedTab)
    .sheet(isPresented: $isSettingsPresented) {
      UserProfileView()
    }
  }
}

@MainActor
private struct DashboardRoot: View {
  @Binding var selectedTab: HomeTab
  @Binding var isSettingsPresented: Bool
  @ObservedObject var budgetStore: BudgetPlannerViewModel
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var searchViewModel = AssetSearchViewModel()
  @StateObject private var activityViewModel = ActivityViewModel()
  @StateObject private var focusPointsViewModel = FocusPointsViewModel()
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

  private var insightCards: [InsightCard] {
    guard let insights = dashboardInsights else {
        return InsightCard.mock
    }

    return [
        .init(
            title: "Savings rate",
            value: "\(Int(insights.savingsRate))%",
            detail: "Based on monthly planned vs actuals.",
            symbol: "arrow.down.circle",
            tint: AppTheme.Colors.success
        ),
        .init(
            title: "Budget streak",
            value: "\(insights.budgetStreak) months",
            detail: "Staying under your spending plan.",
            symbol: "flame",
            tint: .orange
        ),
        .init(
            title: "Watchlist",
            value: "\(insights.watchlistCount) names",
            detail: "Review candidates before earnings.",
            symbol: "star",
            tint: .indigo
        ),
        .init(
            title: "Cash buffer",
            value: insights.cashBuffer.formatted(.currency(code: "USD").presentation(.narrow)),
            detail: "Enough for short-term volatility.",
            symbol: "shield",
            tint: AppTheme.Colors.tint(for: .light)
        )
    ]
  }

  private var greetingText: String {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 5..<12: return "Good morning"
    case 12..<17: return "Good afternoon"
    case 17..<22: return "Good evening"
    default: return "Good night"
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
            DashboardHeroCard(
                totalValue: portfolioTotalValue,
                totalSpending: spendingTotalValue,
                portfolioDeltaPercent: portfolioDeltaPercent,
                spendingDeltaPercent: spendingDeltaPercent,
                portfolioPoints: portfolioChartPoints,
                spendingPoints: spendingChartPoints,
                onPortfolioTap: { selectedTab = .portfolio },
                onExpensesTap: { selectedTab = .expenses },
                onReportsTap: { selectedTab = .reports }
            )
            .redacted(reason: isHomeMetricsLoading && !hasLoadedContent ? .placeholder : [])
          // ... rest of view

          if !searchViewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            AssetSearchCard(viewModel: searchViewModel)
              .transition(.opacity.combined(with: .move(edge: .top)))
          }

          UnifiedActivityFeed(
            viewModel: activityViewModel,
            recentExpenses: budgetStore.recentExpenseActivities,
            financialHealth: dashboardInsights?.financialHealth,
            isFinancialHealthLoading: isInsightsLoading,
            financialHealthUnavailable: insightsLoadFailed
          )

          Button(action: {
              isQuickAddPresented = true
          }) {
              HStack {
                  Image(systemName: "plus.circle.fill")
                  Text("Add Entry")
                      .font(.headline)
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.white.opacity(0.1))
              .clipShape(.rect(cornerRadius: 16))
              .foregroundStyle(.white)
          }

          // Keeping old cards hidden behind a disclosure group or just at the bottom for functionality
          DisclosureGroup("More Insights") {
              VStack(spacing: 20) {
                  InsightsGrid(cards: insightCards)
                  FocusListCard(viewModel: focusPointsViewModel)
              }
              .padding(.top, 16)
          }
          .tint(AppTheme.Colors.tint(for: colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
      }
      .background(MeshGradientBackground())
      .navigationTitle(greetingText)
      .navigationBarTitleDisplayMode(.large)
      .task {
          await loadContent()
      }
      .onChange(of: selectedTab) { _, tab in
        guard tab == .dashboard else { return }
        Task { await loadContent(force: true) }
      }
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button {
            isSettingsPresented = true
          } label: {
            Image(systemName: "gearshape")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
              .padding(6)
              .appGlassEffect(.capsule)
          }
          .accessibilityLabel("Open settings")
        }
      }
      .searchable(
        text: $searchViewModel.query,
        placement: .navigationBarDrawer(displayMode: .always),
        prompt: "Search stocks, ETFs, or owned assets"
      )
      .onChange(of: searchViewModel.query) { _, _ in
        searchViewModel.queryChanged()
      }
      .onSubmit(of: .search) {
        Task { await searchViewModel.searchNow() }
      }
      .sheet(isPresented: $isQuickAddPresented) {
        HomeQuickExpenseSheet { draft in
          await saveQuickExpense(draft)
        }
      }
    }
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

          portfolioChartPoints = portfolioPoints
          spendingChartPoints = spendingPoints
          portfolioTotalValue = portfolioPoints.last?.value ?? 0
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

private struct PortfolioRoot: View {
  @Binding var isSettingsPresented: Bool
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var portfolioViewModel = PortfolioViewModel()
  @State private var selectedSegment: PortfolioSegment = .holdings
  @Namespace private var segmentContentNamespace

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Picker("Portfolio section", selection: $selectedSegment) {
          ForEach(PortfolioSegment.allCases) { segment in
            Text(segment.title).tag(segment)
          }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 8)

        Group {
          switch selectedSegment {
          case .holdings:
            PortfolioScreen()
          case .allocation:
            PortfolioAllocationScreen()
          case .watchlist:
            WatchlistTab()
          case .earnings:
            EarningsCalendarScreen()
          case .news:
            MarketNewsScreen()
          }
        }
        .animation(.snappy(duration: 0.24), value: selectedSegment)
      }
      .environmentObject(portfolioViewModel)
      .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
      .navigationTitle("Portfolio")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button {
            isSettingsPresented = true
          } label: {
            Image(systemName: "gearshape")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
              .padding(6)
              .appGlassEffect(.capsule)
          }
          .accessibilityLabel("Open settings")
        }
      }
    }
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
  @State private var showingPortfolio = true

  private var currentTitle: String {
    showingPortfolio ? "Total Wealth" : "Monthly Spending"
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
    guard let currentDeltaPercent else { return "No baseline for trend yet" }
    let sign = currentDeltaPercent > 0 ? "+" : ""
    let percent = (currentDeltaPercent * 100).formatted(.number.precision(.fractionLength(1)))
    return "\(sign)\(percent)% vs last period"
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
                Text("Portfolio")
                    .font(.subheadline)
                    .foregroundStyle(showingPortfolio ? .primary : .secondary)
                    .padding(.trailing, 8)

                Toggle("", isOn: $showingPortfolio)
                    .labelsHidden()
                    .tint(.white.opacity(0.8))

                Text("Spending")
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
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12)
  ]

  var body: some View {
    LazyVGrid(columns: columns, spacing: 12) {
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
              .typography(.nano)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }
}

private struct FocusListCard: View {
  @ObservedObject var viewModel: FocusPointsViewModel
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
            .onSubmit {
              Task { await viewModel.createFromDraft() }
            }

          Button {
            Task { await viewModel.createFromDraft() }
          } label: {
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
        .appGlassEffect(.rect(cornerRadius: 12))

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
              if item.statusUpdatedBy != .system {
                Task { await viewModel.toggleStatus(for: item) }
              }
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
            }
            .buttonStyle(.plain)
            .disabled(item.statusUpdatedBy == .system && item.status == .completed)
          }
        }
      }
    }
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
    Button(action: action) {
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
      .padding(.vertical, 12)
      .appGlassEffect(.rect(cornerRadius: 18), tint: tint.opacity(0.10))
      .opacity(isDisabled ? 0.6 : 1.0)
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
  }
}

// MARK: - Models

private struct PortfolioTrendPoint: Identifiable {
  let label: String
  let value: Double

  var id: String { label }

  // to fill from endpoint later
  static let mock: [PortfolioTrendPoint] = [
    .init(label: "Mon", value: 112_300),
    .init(label: "Tue", value: 113_840),
    .init(label: "Wed", value: 113_120),
    .init(label: "Thu", value: 114_680),
    .init(label: "Fri", value: 116_020),
    .init(label: "Sat", value: 118_920),
    .init(label: "Sun", value: 124_830)
  ]
}

private struct SpendingPoint: Identifiable {
  let label: String
  let value: Double

  var id: String { label }

  // to fill from endpoint later
  static let mock: [SpendingPoint] = [
    .init(label: "Jan", value: 980),
    .init(label: "Feb", value: 860),
    .init(label: "Mar", value: 780),
    .init(label: "Apr", value: 910)
  ]
}

private struct InsightCard: Identifiable {
  let title: String
  let value: String
  let detail: String
  let symbol: String
  let tint: Color

  var id: String { title }

  // to fill from endpoint later
  static let mock: [InsightCard] = [
    .init(
      title: "Savings rate",
      value: "28%",
      detail: "Holding steady over the last quarter.",
      symbol: "arrow.down.circle",
      tint: AppTheme.Colors.success
    ),
    .init(
      title: "Budget streak",
      value: "4 months",
      detail: "Staying under your spending plan.",
      symbol: "flame",
      tint: .orange
    ),
    .init(
      title: "Watchlist",
      value: "12 names",
      detail: "Review candidates before earnings.",
      symbol: "star",
      tint: .indigo
    ),
    .init(
      title: "Cash buffer",
      value: "$9.4K",
      detail: "Enough for short-term volatility.",
      symbol: "shield",
      tint: AppTheme.Colors.tint(for: .light)
    )
  ]
}
