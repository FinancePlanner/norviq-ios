import Charts
import Combine
import Foundation
import StoreKit
import SwiftUI
import StockPlanShared
import Factory

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

      ExpensesComparisonScreen(isSettingsPresented: $isSettingsPresented, viewModel: budgetPlannerViewModel)
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
  @State private var isProfilePresented = false
  @State private var dashboardData: DashboardResponse?
  
  private let dashboardService: any DashboardServicing = Container.shared.dashboardService()

  // to fill from endpoint later
  private let trendPoints = PortfolioTrendPoint.mock
  // to fill from endpoint later
  private let spendingPoints = SpendingPoint.mock
  // to fill from endpoint later
  private let insightCards = InsightCard.mock

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
                    onPortfolioTap: { selectedTab = .portfolio },
                    onExpensesTap: { selectedTab = .expenses },
                    onReportsTap: { selectedTab = .reports }
                )
            } else {
                // Loading / Error UI
                DashboardHeroCard(
                    totalValue: 0,
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

          UnifiedActivityFeed()

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
                  FocusListCard()
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
          do {
              self.dashboardData = try await dashboardService.getDashboard()
          } catch {
              // Handle error
          }
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

          AppTopBarProfileButton(
            isUserMenuPresented: isProfilePresented,
            onTap: { isProfilePresented = true }
          )
          .accessibilityLabel("Open profile")
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
      .task {
        await portfolioViewModel.load()
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

          AppTopBarProfileButton(
            isUserMenuPresented: isProfilePresented,
            onTap: { isProfilePresented = true }
          )
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
  let onPortfolioTap: () -> Void
  let onExpensesTap: () -> Void
  let onReportsTap: () -> Void

  @Environment(\.colorScheme) private var colorScheme
  @State private var showingPortfolio = true
  
  private var mockChartData: [ChartDataPoint] {
      let calendar = Calendar.current
      let today = Date()
      let baseValue = totalValue == 0 ? 100000.0 : totalValue
      
      return (0..<30).map { i in
          let date = calendar.date(byAdding: .day, value: -(29 - i), to: today)!
          let noise = sin(Double(i) * 0.5) * 5000.0 + Double.random(in: -1000...1000)
          let trend = Double(i) * 300.0
          return ChartDataPoint(date: date, value: max(0, baseValue * 0.8 + noise + trend))
      }
  }

  var body: some View {
    GlassCard(cornerRadius: 28) {
      VStack(alignment: .leading, spacing: 18) {
        Text("Total Wealth")
          .typography(.small, weight: .semibold)
          .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 8) {
          Text(totalValue.currency)
            .typography(.display, weight: .bold)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .contentTransition(.numericText())

          HStack(spacing: 4) {
            Image(systemName: "arrow.up.right")
            Text("+2.31% ($2,816.32)")
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.green)
        }
        
        InteractiveLineChart(data: mockChartData, color: .green)
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

private struct UnifiedActivityFeed: View {
    let activities: [ActivityFeedItem] = [
        ActivityFeedItem(title: "AAPL", subtitle: "Stock Growth", amount: 175.30, isGrowth: true, symbol: "arrow.up.right", time: "Today, 10:15 AM"),
        ActivityFeedItem(title: "Starbucks Coffee", subtitle: "Groceries & Dining", amount: -5.90, isGrowth: false, symbol: "bag.fill", time: "Today, 9:30 AM"),
        ActivityFeedItem(title: "GOOGL", subtitle: "Dividend", amount: 42.50, isGrowth: true, symbol: "arrow.up.right", time: "Today, 9:00 AM"),
        ActivityFeedItem(title: "Electric Bill", subtitle: "Utilities", amount: -120.00, isGrowth: false, symbol: "lightbulb.fill", time: "Today, 8:45 AM")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Feed")
                .font(.title2.bold())
                .padding(.horizontal, 4)
                
            GlassCard(cornerRadius: 22) {
                VStack(spacing: 0) {
                    ForEach(activities) { activity in
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
                                Text(activity.amount > 0 ? "+\(activity.amount.currency)" : "-\(abs(activity.amount).currency)")
                                    .font(.headline)
                                    .foregroundStyle(activity.isGrowth ? .green : .red)
                                Text(activity.time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 12)
                        
                        if activity.id != activities.last?.id {
                            Divider()
                                .padding(.leading, 60)
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
                            .trim(from: 0, to: 0.85)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("85")
                            .font(.headline)
                    }
                    .frame(width: 50, height: 50)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("85/100 - Healthy")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Text("Financial Health")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct HomeExpensesInteractiveChartCard: View {
  private var mockExpensesChartData: [ChartDataPoint] {
      let calendar = Calendar.current
      let today = Date()
      let baseValue = 3500.0
      
      return (0..<30).map { i in
          let date = calendar.date(byAdding: .day, value: -(29 - i), to: today)!
          let noise = sin(Double(i) * 0.8) * 500.0 + Double.random(in: -200...200)
          let trend = Double(i) * 15.0
          return ChartDataPoint(date: date, value: max(0, baseValue * 0.5 + noise + trend))
      }
  }

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
        
        InteractiveLineChart(data: mockExpensesChartData, color: .purple)
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
  // to fill from endpoint later
  private let items = [
    "Review watchlist names before next earnings window.",
    "Keep discretionary spend below 12% of take-home this month.",
    "Prioritize high-conviction holdings over fragmented small positions.",
  ]

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 14) {
        Text("Focus this week")
          .typography(.small, weight: .semibold)

        ForEach(items, id: \.self) { item in
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(AppTheme.Colors.success)
            Text(item)
              .typography(.small)
              .frame(maxWidth: .infinity, alignment: .leading)
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
