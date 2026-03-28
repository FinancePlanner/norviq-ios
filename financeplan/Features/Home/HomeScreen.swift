import Charts
import Combine
import Foundation
import SwiftUI

private enum HomeTab: Hashable {
  case dashboard
  case portfolio
  case expenses
  case reports
  case settings
}

private enum PortfolioSegment: String, CaseIterable, Identifiable {
  case holdings
  case allocation
  case watchlist

  var id: String { rawValue }

  var title: String {
    switch self {
    case .holdings:
      "Holdings"
    case .allocation:
      "Allocation"
    case .watchlist:
      "Watchlist"
    }
  }
}

@MainActor
struct HomeScreen: View {
  let onLogout: () async -> Void

  @Environment(\.colorScheme) private var colorScheme
  @State private var selectedTab: HomeTab = .dashboard
  @StateObject private var budgetPlannerViewModel = BudgetPlannerViewModel()

  var body: some View {
    TabView(selection: $selectedTab) {
      DashboardRoot(selectedTab: $selectedTab)
        .tabItem {
          Label("Home", systemImage: "house")
        }
        .tag(HomeTab.dashboard)

      PortfolioRoot()
        .tabItem {
          Label("Portfolio", systemImage: "chart.line.uptrend.xyaxis")
        }
        .tag(HomeTab.portfolio)

      ExpensesPlannerScreen(viewModel: budgetPlannerViewModel)
        .tabItem {
          Label("Expenses", systemImage: "creditcard")
        }
        .tag(HomeTab.expenses)

      ExpensesComparisonScreen(viewModel: budgetPlannerViewModel)
        .tabItem {
          Label("Reports", systemImage: "chart.bar.xaxis")
        }
        .tag(HomeTab.reports)

      NavigationStack {
        SettingsDetailView(onLogout: onLogout)
      }
      .tabItem {
        Label("Settings", systemImage: "gearshape")
      }
      .tag(HomeTab.settings)
    }
    .tint(AppTheme.Colors.tint(for: colorScheme))
    .toolbarBackground(.visible, for: .tabBar)
    .toolbarBackground(AppTheme.Colors.tabBarBackground(for: colorScheme), for: .tabBar)
    .animation(.snappy(duration: 0.28), value: selectedTab)
  }
}

@MainActor
private struct DashboardRoot: View {
  @Binding var selectedTab: HomeTab
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var searchViewModel = AssetSearchViewModel()
  @State private var isProfilePresented = false

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
          DashboardHeroCard(
            onPortfolioTap: { selectedTab = .portfolio },
            onExpensesTap: { selectedTab = .expenses },
            onReportsTap: { selectedTab = .reports }
          )

          if !searchViewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            AssetSearchCard(viewModel: searchViewModel)
              .transition(.opacity.combined(with: .move(edge: .top)))
          }

          TrendOverviewCard(
            title: "Portfolio outlook",
            subtitle: "Planned value over the last 7 checkpoints",
            points: trendPoints,
            accent: AppTheme.Colors.tint(for: colorScheme)
          )

          SpendingSnapshotCard(points: spendingPoints)

          InsightsGrid(cards: insightCards)

          FocusListCard()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
      }
      .background(MeshGradientBackground())
      .navigationTitle(greetingText)
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
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
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var portfolioViewModel = PortfolioViewModel()
  @State private var selectedSegment: PortfolioSegment = .holdings
  @State private var isProfilePresented = false

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
              .transition(.opacity.combined(with: .move(edge: .leading)))
          case .allocation:
            PortfolioAllocationScreen()
              .transition(.opacity)
          case .watchlist:
            WatchlistTab()
              .transition(.opacity.combined(with: .move(edge: .trailing)))
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
        ToolbarItem(placement: .topBarTrailing) {
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
  @State private var isLoggingOut = false
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

      Section("Privacy") {
        LabeledContent("Data handling", value: "Local-first planning UI")
        LabeledContent("Sensitive actions", value: "Biometric-friendly")
        LabeledContent("Motion", value: "Reduced when accessibility requests it")
      }

      Section("Support") {
        Label("Help & Support", systemImage: "questionmark.circle")
        Label("About FinPlanner", systemImage: "info.circle")
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
  let onPortfolioTap: () -> Void
  let onExpensesTap: () -> Void
  let onReportsTap: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GlassCard(cornerRadius: 28) {
      VStack(alignment: .leading, spacing: 18) {
        Text("Financial snapshot")
          .typography(.small, weight: .semibold)
          .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 8) {
          // to fill from endpoint later
          Text("$124,830.42")
            .typography(.display, weight: .bold)
            .minimumScaleFactor(0.7)
            .lineLimit(1)

          HStack(spacing: 10) {
            // to fill from endpoint later
            Label("+2.31%", systemImage: "arrow.up.right")
              .typography(.small, weight: .semibold)
              .foregroundStyle(AppTheme.Colors.success)

            // to fill from endpoint later
            Text("Monthly budget is 15% under plan")
              .typography(.small)
              .foregroundStyle(.secondary)
          }
        }

        HStack(spacing: 10) {
          DashboardActionButton(
            title: "Portfolio",
            symbol: "chart.line.uptrend.xyaxis",
            tint: AppTheme.Colors.tint(for: colorScheme),
            action: onPortfolioTap
          )
          DashboardActionButton(
            title: "Expenses",
            symbol: "creditcard",
            tint: AppTheme.Colors.secondaryTint(for: colorScheme),
            action: onExpensesTap
          )
          DashboardActionButton(
            title: "Reports",
            symbol: "chart.bar.xaxis",
            tint: .indigo,
            action: onReportsTap
          )
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct TrendOverviewCard: View {
  let title: String
  let subtitle: String
  let points: [PortfolioTrendPoint]
  let accent: Color

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        Text(title)
          .typography(.small, weight: .semibold)
        Text(subtitle)
          .typography(.nano)
          .foregroundStyle(.secondary)

        Chart(points) { point in
          LineMark(
            x: .value("Date", point.label),
            y: .value("Value", point.value)
          )
          .interpolationMethod(.catmullRom)
          .foregroundStyle(accent)
          .lineStyle(.init(lineWidth: 3))

          AreaMark(
            x: .value("Date", point.label),
            y: .value("Value", point.value)
          )
          .interpolationMethod(.catmullRom)
          .foregroundStyle(
            LinearGradient(
              colors: [accent.opacity(0.24), .clear],
              startPoint: .top,
              endPoint: .bottom
            )
          )
        }
        .frame(height: 190)
        .chartYAxis {
          AxisMarks(position: .leading)
        }
      }
    }
  }
}

private struct SpendingSnapshotCard: View {
  let points: [SpendingPoint]

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 16) {
        Text("Spending trend")
          .typography(.small, weight: .semibold)

        Chart(points) { point in
          BarMark(
            x: .value("Month", point.label),
            y: .value("Amount", point.value)
          )
          .foregroundStyle(
            point.value <= 900 ? AppTheme.Colors.success : AppTheme.Colors.warning
          )
          .cornerRadius(8)
        }
        .frame(height: 180)
        .chartYAxis {
          AxisMarks(position: .leading)
        }

        Text("Glanceable month-by-month comparison keeps expense review readable at a glance.")
          .typography(.nano)
          .foregroundStyle(.secondary)
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
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: symbol)
          .font(.headline.weight(.semibold))
        Text(title)
          .typography(.nano, weight: .semibold)
      }
      .foregroundStyle(tint)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(.plain)
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
