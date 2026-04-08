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
      DashboardRoot(selectedTab: $selectedTab, isSettingsPresented: $isSettingsPresented)
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
      NavigationStack {
        SettingsDetailView(onLogout: onLogout)
      }
    }
  }
}

@MainActor
private struct DashboardRoot: View {
  @Binding var selectedTab: HomeTab
  @Binding var isSettingsPresented: Bool
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var searchViewModel = AssetSearchViewModel()
  @StateObject private var activityViewModel = ActivityViewModel()
  @StateObject private var focusPointsViewModel = FocusPointsViewModel()
  @State private var isProfilePresented = false
  @State private var dashboardData: DashboardResponse?
  @State private var dashboardInsights: DashboardInsightsResponse?
  @State private var isInsightsLoading = false
  @State private var insightsLoadFailed = false
  @State private var portfolioChartPoints: [ChartDataPoint] = []
  @State private var spendingChartPoints: [ChartDataPoint] = []
  @State private var hasLoadedContent = false
  
  private let dashboardService: any DashboardServicing = Container.shared.dashboardService()
  
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
        ),
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
            if let dashboard = dashboardData {
                DashboardHeroCard(
                    totalValue: dashboard.totalValue,
                    totalSpending: 3250.45,
                    portfolioPoints: portfolioChartPoints,
                    spendingPoints: spendingChartPoints,
                    onPortfolioTap: { selectedTab = .portfolio },
                    onExpensesTap: { selectedTab = .expenses },
                    onReportsTap: { selectedTab = .reports }
                )
            } else {
                // Loading / Error UI
                DashboardHeroCard(
                    totalValue: 0,
                    totalSpending: 0,
                    portfolioPoints: [],
                    spendingPoints: [],
                    onPortfolioTap: { selectedTab = .portfolio },
                    onExpensesTap: { selectedTab = .expenses },
                    onReportsTap: { selectedTab = .reports }
                )
                .redacted(reason: .placeholder)
            }
          // ... rest of view

          if !searchViewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            AssetSearchCard(viewModel: searchViewModel)
              .transition(.opacity.combined(with: .move(edge: .top)))
          }

          UnifiedActivityFeed(
            viewModel: activityViewModel,
            financialHealth: dashboardInsights?.financialHealth,
            isFinancialHealthLoading: isInsightsLoading,
            financialHealthUnavailable: insightsLoadFailed
          )

          Button(action: {
              // Action for adding entry
          }) {
              HStack {
                  Image(systemName: "plus.circle.fill")
                  Text("Add Entry")
                      .font(.headline)
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.white.opacity(0.1))
              .cornerRadius(16)
              .foregroundStyle(.white)
          }

          // Keeping old cards hidden behind a disclosure group or just at the bottom for functionality
          DisclosureGroup("More Insights") {
              VStack(spacing: 20) {
                  HomeExpensesInteractiveChartCard()
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
        prompt: "Search stocks or ETFs"
      )
      .onChange(of: searchViewModel.query) { _ in
        searchViewModel.queryChanged()
      }
      .onSubmit(of: .search) {
        Task { await searchViewModel.searchNow() }
      }
      .sheet(isPresented: $isProfilePresented) {
        UserProfileView()
      }
    }
  }

  private func loadContent(force: Bool = false) async {
      guard force || !hasLoadedContent else { return }
      if spendingChartPoints.isEmpty {
          spendingChartPoints = Self.makeSpendingPoints()
      }

      async let dashboardLoad: Void = loadDashboard()
      async let insightsLoad: Void = loadInsights()
      async let activityLoad: Void = activityViewModel.loadActivities()
      async let focusPointsLoad: Void = focusPointsViewModel.load()
      _ = await (dashboardLoad, insightsLoad, activityLoad, focusPointsLoad)
      hasLoadedContent = true
  }

  private func loadDashboard() async {
      let start = ContinuousClock.now
      do {
          let dashboard = try await dashboardService.getDashboard()
          dashboardData = dashboard
          portfolioChartPoints = Self.makePortfolioPoints(totalValue: dashboard.totalValue)
      } catch {
          homePerformanceLogger.error("Dashboard load failed: \(error.localizedDescription, privacy: .public)")
      }

      homePerformanceLogger.info(
          "Dashboard load duration_ms=\(Self.durationInMilliseconds(from: start.duration(to: .now)), privacy: .public)"
      )
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

  private static func makePortfolioPoints(totalValue: Double, days: Int = 30) -> [ChartDataPoint] {
      let calendar = Calendar.current
      let today = Date()
      let base = totalValue > 0 ? totalValue : 100_000

      return (0..<days).compactMap { index in
          guard let date = calendar.date(byAdding: .day, value: -(days - 1 - index), to: today) else {
              return nil
          }
          let seasonal = sin(Double(index) * 0.45) * base * 0.025
          let trend = Double(index) * (base * 0.0015)
          let value = max(0, base * 0.78 + seasonal + trend)
          return ChartDataPoint(date: date, value: value)
      }
  }

  private static func makeSpendingPoints(days: Int = 30) -> [ChartDataPoint] {
      let calendar = Calendar.current
      let today = Date()
      let base = 3_500.0

      return (0..<days).compactMap { index in
          guard let date = calendar.date(byAdding: .day, value: -(days - 1 - index), to: today) else {
              return nil
          }
          let seasonal = sin(Double(index) * 0.8) * 450
          let trend = Double(index) * 14
          let value = max(0, base * 0.55 + seasonal + trend)
          return ChartDataPoint(date: date, value: value)
      }
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
  @State private var isProfilePresented = false
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
      .sheet(isPresented: $isProfilePresented) {
        UserProfileView()
      }
    }
  }
}

// MARK: - Settings

private struct SettingsDetailView: View {
  let onLogout: () async -> Void

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.requestReview) private var requestReview
  @State private var isLoggingOut = false
  @State private var isFeedbackPresented = false
  @AppStorage(AppAppearance.storageKey) private var appAppearanceRawValue = AppAppearance.system
    .rawValue

  var body: some View {
    List {
      // MARK: - User Card (Apple Settings style)
      Section {
        NavigationLink {
          UserProfileView()
        } label: {
          HStack(spacing: 14) {
            // Avatar
            ZStack {
              Circle()
                .fill(
                  LinearGradient(
                    colors: AppTheme.avatarGradient(for: colorScheme),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
                .frame(width: 56, height: 56)

              Image(systemName: "person.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
              Text("Your Profile")
                .typography(.label, weight: .semibold)
              Text("View and edit your account")
                .typography(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .padding(.vertical, 4)
        }
      }

      Section("Security") {
        Label("Face ID ready", systemImage: "faceid")
          .foregroundStyle(.primary)
      }

      Section("Appearance") {
        Picker("Appearance", selection: appAppearanceBinding) {
          ForEach(AppAppearance.allCases, id: \.self) { appearance in
            Text(appearance.title)
              .tag(appearance)
          }
        }
        .pickerStyle(.segmented)

        Text(selectedAppearance.subtitle)
          .typography(.caption)
          .foregroundStyle(.secondary)
      }

      Section("Integrations") {
        LabeledContent {
           Text("Soon")
               .typography(.caption, weight: .bold)
               .foregroundStyle(.white)
               .padding(.horizontal, 6)
               .padding(.vertical, 2)
               .background(Color.indigo, in: Capsule())
        } label: {
           Label("Claude, ChatGPT, Grok", systemImage: "sparkles")
               .foregroundStyle(.primary)
        }
      }

      Section("Privacy") {
        LabeledContent("Data handling", value: "Local-first planning UI")
        LabeledContent("Sensitive actions", value: "Biometric-friendly")
        LabeledContent("Motion", value: "Reduced when accessibility requests it")
      }

      Section("Support") {
        Label("Help & Support", systemImage: "questionmark.circle")

        Button {
          isFeedbackPresented = true
        } label: {
          Label("Share Feedback", systemImage: "quote.bubble")
        }
        .foregroundStyle(.primary)

        Button {
          requestReview()
        } label: {
          Label("Leave a review", systemImage: "star.fill")
        }
        .foregroundStyle(.primary)

        Label("About Norviqa", systemImage: "info.circle")
      }

      Section("Connect") {
        Link(destination: URL(string: "mailto:support@norviqa.com")!) {
          Label("Email Support", systemImage: "envelope")
        }
        .foregroundStyle(.primary)

        Link(destination: URL(string: "https://discord.gg/norviqa")!) {
          Label("Join Discord", systemImage: "bubble.left.and.bubble.right")
        }
        .foregroundStyle(.primary)

        Link(destination: URL(string: "https://x.com/norviqa")!) {
          Label("Follow on X", systemImage: "x.circle")
        }
        .foregroundStyle(.primary)
      }

      Section {
        Button(role: .destructive) {
          Task {
            guard !isLoggingOut else { return }
            isLoggingOut = true
            await onLogout()
            isLoggingOut = false
          }
        } label: {
          HStack(spacing: 8) {
            if isLoggingOut {
              ProgressView()
            }
            Text("Log out")
              .typography(.button, weight: .semibold)
          }
          .frame(maxWidth: .infinity, alignment: .center)
          .foregroundStyle(AppTheme.Colors.danger)
        }
        .disabled(isLoggingOut)
      }
    }
    .scrollContentBackground(.hidden)
    .listStyle(.insetGrouped)
    .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.large)
    .sheet(isPresented: $isFeedbackPresented) {
      FeedbackSheet()
    }
  }

  private var appAppearanceBinding: Binding<AppAppearance> {
    Binding(
      get: { AppAppearance.from(appAppearanceRawValue) },
      set: { appAppearanceRawValue = $0.rawValue }
    )
  }

  private var selectedAppearance: AppAppearance {
    AppAppearance.from(appAppearanceRawValue)
  }
}

// MARK: - Dashboard cards

private struct DashboardHeroCard: View {
  let totalValue: Double
  let totalSpending: Double
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
  
  private var currentColor: Color {
    showingPortfolio ? .green : .purple
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
            Image(systemName: showingPortfolio ? "arrow.up.right" : "arrow.down.right")
            Text(showingPortfolio ? "+2.31% ($2,816.32)" : "-12.4% vs last month")
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(showingPortfolio ? .green : .green) // Green even for spending if it's down
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

// Activity Feed Item model for mock data
struct ActivityFeedItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let amount: Double
    let isGrowth: Bool
    let symbol: String
    let time: String
}

enum FinancialHealthCardTone: Equatable {
    case success
    case warning
    case critical
    case neutral
}

struct FinancialHealthCardState: Equatable {
    let scoreText: String
    let summaryText: String
    let tone: FinancialHealthCardTone
    let ringProgress: Double

    init(
        health: DashboardFinancialHealthDTO?,
        isLoading: Bool,
        isUnavailable: Bool
    ) {
        if isLoading {
            self.scoreText = "--"
            self.summaryText = "--/100"
            self.tone = .neutral
            self.ringProgress = 0
            return
        }

        if isUnavailable || health == nil {
            self.scoreText = "--"
            self.summaryText = "--/100 - Unavailable"
            self.tone = .neutral
            self.ringProgress = 0
            return
        }

        guard let health else {
            self.scoreText = "--"
            self.summaryText = "--/100 - Unavailable"
            self.tone = .neutral
            self.ringProgress = 0
            return
        }

        self.scoreText = "\(health.score)"
        self.summaryText = "\(health.score)/\(health.maxScore) - \(Self.statusTitle(health.status))"
        self.ringProgress = health.maxScore > 0
            ? min(max(Double(health.score) / Double(health.maxScore), 0), 1)
            : 0

        switch health.status {
        case .healthy, .excellent:
            self.tone = .success
        case .needsAttention:
            self.tone = .warning
        case .atRisk:
            self.tone = .critical
        }
    }

    private static func statusTitle(_ status: FinancialHealthStatus) -> String {
        switch status {
        case .atRisk:
            return "At Risk"
        case .needsAttention:
            return "Needs Attention"
        case .healthy:
            return "Healthy"
        case .excellent:
            return "Excellent"
        }
    }
}

private struct UnifiedActivityFeed: View {
    @ObservedObject var viewModel: ActivityViewModel
    let financialHealth: DashboardFinancialHealthDTO?
    let isFinancialHealthLoading: Bool
    let financialHealthUnavailable: Bool

    private var financialHealthCardState: FinancialHealthCardState {
        FinancialHealthCardState(
            health: financialHealth,
            isLoading: isFinancialHealthLoading,
            isUnavailable: financialHealthUnavailable
        )
    }

    private var healthTint: Color {
        switch financialHealthCardState.tone {
        case .success:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        case .neutral:
            return .secondary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Feed")
                .font(.title2.bold())
                .padding(.horizontal, 4)
                
            GlassCard(cornerRadius: 22) {
                VStack(spacing: 0) {
                    if viewModel.isLoading && viewModel.activities.isEmpty {
                        ProgressView()
                            .padding()
                    } else if viewModel.activities.isEmpty {
                        Text("No recent activity")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(viewModel.activities) { activity in
                            HStack(spacing: 16) {
                                Circle()
                                    .fill(activity.isGrowth ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: activity.symbol)
                                            .foregroundStyle(activity.isGrowth ? .green : .red)
                                            .font(.title3)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(activity.title)
                                        .font(.headline)
                                    Text(activity.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    if let amount = activity.amount {
                                        Text(amount > 0 ? "+\(amount.currency)" : "-\(abs(amount).currency)")
                                            .font(.headline)
                                            .foregroundStyle(activity.isGrowth ? .green : .red)
                                    }
                                    Text(activity.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 12)
                            
                            if activity.id != viewModel.activities.last?.id {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                }
            }
            
            // Financial Health summary placeholder
            GlassCard(cornerRadius: 22) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: financialHealthCardState.ringProgress)
                            .stroke(healthTint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.35), value: financialHealthCardState.ringProgress)
                        Text(financialHealthCardState.scoreText)
                            .font(.headline)
                    }
                    .frame(width: 50, height: 50)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(financialHealthCardState.summaryText)
                            .font(.headline)
                            .foregroundStyle(healthTint)
                        Text("Financial Health")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .redacted(reason: isFinancialHealthLoading ? .placeholder : [])
            .scaleEffect(isFinancialHealthLoading ? 0.99 : 1)
            .opacity(isFinancialHealthLoading ? 0.9 : 1)
            .animation(.easeOut(duration: 0.25), value: isFinancialHealthLoading)
        }
    }
}

private struct HomeExpensesInteractiveChartCard: View {
  private static let mockExpensesChartData: [ChartDataPoint] = {
      let calendar = Calendar.current
      let today = Date()
      let baseValue = 3500.0

      return (0..<30).compactMap { i in
          guard let date = calendar.date(byAdding: .day, value: -(29 - i), to: today) else {
              return nil
          }
          let wave = sin(Double(i) * 0.8) * 500.0
          let secondaryWave = cos(Double(i) * 0.35) * 140.0
          let trend = Double(i) * 15.0
          return ChartDataPoint(date: date, value: max(0, baseValue * 0.5 + wave + secondaryWave + trend))
      }
  }()

  var body: some View {
    GlassCard(cornerRadius: 22) {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Expenses trend")
            .typography(.small, weight: .semibold)
            .foregroundStyle(.secondary)
          
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(3250.45.currency)
              .typography(.hero, weight: .bold)
              .contentTransition(.numericText())
            Text("this month")
              .typography(.small)
              .foregroundStyle(.secondary)
          }
          
          HStack(spacing: 4) {
            Image(systemName: "arrow.down.right")
            Text("-12.4% vs last month")
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.green)
        }
        .padding(.horizontal, 4)
        
        InteractiveLineChart(data: Self.mockExpensesChartData, color: .purple)
          .frame(height: 160)
          .padding(.horizontal, -12) // Bleed to edges of card padding
      }
    }
  }
}

private struct InsightsGrid: View {
  let cards: [InsightCard]

  private let columns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12),
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
          Text("No connected asset search results yet.")
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
    .init(label: "Sun", value: 124_830),
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
    .init(label: "Apr", value: 910),
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
    ),
  ]
}
