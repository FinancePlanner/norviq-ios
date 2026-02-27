import Charts
import SwiftUI
import Foundation

private enum HomeTab: Hashable {
  case dashboard
  case portfolio
  case watchlist
  case more
}

struct HomeScreen: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @Environment(\.colorScheme) private var colorScheme
  let onLogout: () async -> Void
  @State private var selectedTab: HomeTab = .dashboard
  @State private var isMoreSheetPresented = false

  var body: some View {
    VStack(spacing: 0) {
      AppTopBar(username: sessionManager.username)

      TabView(selection: $selectedTab) {
        NavigationStack {
          DashboardTab()
            .navigationBarHidden(true)
        }
        .tabItem {
          Label("Home", systemImage: "house.fill")
        }
        .tag(HomeTab.dashboard)

        NavigationStack {
          PortfolioTab()
            .navigationBarHidden(true)
        }
        .tabItem {
          Label("Portfolio", systemImage: "briefcase.fill")
        }
        .tag(HomeTab.portfolio)

        NavigationStack {
          WatchlistTab()
            .navigationBarHidden(true)
        }
        .tabItem {
          Label("Watchlist", systemImage: "star.fill")
        }
        .tag(HomeTab.watchlist)

        Color.clear
          .tabItem {
            Label("More", systemImage: "ellipsis")
          }
          .tag(HomeTab.more)
      }
      .tint(AppTheme.Colors.tint(for: colorScheme))
      .toolbarBackground(.visible, for: .tabBar)
      .toolbarBackground(AppTheme.Colors.tabBarBackground(for: colorScheme), for: .tabBar)
      .onChange(of: selectedTab) { newValue in
        if newValue == .more {
          isMoreSheetPresented = true
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            selectedTab = .dashboard
          }
        }
      }
    }
    .ignoresSafeArea(.keyboard)
    .sheet(isPresented: $isMoreSheetPresented) {
      MoreSheet(onLogout: onLogout)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
  }
}

// MARK: - More Sheet

private struct MoreSheet: View {
  let onLogout: () async -> Void
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          NavigationLink {
            SettingsDetailView(onLogout: onLogout)
          } label: {
            Label("Settings", systemImage: "gearshape.fill")
          }
        }

        Section {
          NavigationLink {
            Text("Help & Support")
              .navigationTitle("Help")
          } label: {
            Label("Help & Support", systemImage: "questionmark.circle")
          }

          NavigationLink {
            Text("About FinPlanner")
              .navigationTitle("About")
          } label: {
            Label("About", systemImage: "info.circle")
          }
        }
      }
      .navigationTitle("More")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
        }
      }
    }
  }
}

// MARK: - Settings Detail View

private struct SettingsDetailView: View {
  let onLogout: () async -> Void
  @Environment(\.colorScheme) private var colorScheme
  @State private var isLoggingOut = false
  @AppStorage(AppAppearance.storageKey) private var appAppearanceRawValue = AppAppearance.system
    .rawValue

  var body: some View {
    List {
      Section("Account") {
        Text("Signed in to FinPlanner")
          .typography(.small)
          .foregroundStyle(.secondary)
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

      Section {
        Button {
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
                .tint(.white)
            }
            Text("Log out")
              .typography(.button, weight: .semibold)
          }
          .frame(maxWidth: .infinity)
          .foregroundStyle(AppTheme.Colors.danger)
        }
        .disabled(isLoggingOut)
      }
    }
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Tab Content Views

private struct DashboardTab: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ScrollView {
      VStack(spacing: 14) {
        PortfolioSummaryWidget()
        DailyPerformanceWidget()
        TopMoversWidget()
        AllocationWidget()
      }
      .padding(16)
    }
    .background(MeshGradientBackground().ignoresSafeArea())
  }
}

private struct PortfolioTab: View {
  @Environment(\.colorScheme) private var colorScheme

  private let positions: [PortfolioPosition] = [
    .init(symbol: "AAPL", quantity: 18, averageCost: 168.20, marketPrice: 191.70),
    .init(symbol: "MSFT", quantity: 7, averageCost: 352.00, marketPrice: 418.30),
    .init(symbol: "NVDA", quantity: 12, averageCost: 98.40, marketPrice: 125.60),
    .init(symbol: "AMZN", quantity: 10, averageCost: 157.15, marketPrice: 177.10),
  ]

  var body: some View {
    List(positions) { position in
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(position.symbol)
            .typography(.label, weight: .semibold)
          Spacer()
          Text(position.marketValue.currency)
            .typography(.small, weight: .semibold)
        }

        HStack(spacing: 10) {
          Text("Qty \(Int(position.quantity))")
          Text("Avg \(position.averageCost.currency)")
          Text("Now \(position.marketPrice.currency)")
        }
        .typography(.nano)
        .foregroundStyle(.secondary)

        Text(position.unrealizedPnLString)
          .typography(.nano, weight: .semibold)
          .foregroundStyle(
            position.unrealizedPnL >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger)
      }
      .padding(.vertical, 4)
    }
    .scrollContentBackground(.hidden)
    .background(AppTheme.Colors.pageBackground(for: colorScheme))
  }
}

private struct WatchlistTab: View {
  @Environment(\.colorScheme) private var colorScheme

  private let watchlist: [WatchlistItem] = [
    .init(symbol: "TSLA", price: 241.80, changePercent: 1.92),
    .init(symbol: "META", price: 502.40, changePercent: -0.64),
    .init(symbol: "AMD", price: 176.25, changePercent: 2.15),
    .init(symbol: "GOOGL", price: 186.91, changePercent: 0.43),
  ]

  var body: some View {
    List(watchlist) { item in
      HStack {
        Text(item.symbol)
          .typography(.label, weight: .semibold)
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text(item.price.currency)
            .typography(.small, weight: .semibold)
          Text(item.changePercentString)
            .typography(.nano, weight: .semibold)
            .foregroundStyle(
              item.changePercent >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger)
        }
      }
      .padding(.vertical, 2)
    }
    .scrollContentBackground(.hidden)
    .background(AppTheme.Colors.pageBackground(for: colorScheme))
  }
}

// MARK: - Dashboard Widgets

private struct PortfolioSummaryWidget: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 10) {
      Text("Portfolio Value")
        .typography(.nano)
        .foregroundStyle(.secondary)

      Text("$124,830.42")
        .typography(.hero, weight: .bold)

      HStack(spacing: 8) {
        Label("+$2,814.11", systemImage: "arrow.up.right")
          .typography(.small, weight: .semibold)
          .foregroundStyle(AppTheme.Colors.success)

        Text("(+2.31%) today")
          .typography(.small)
          .foregroundStyle(.secondary)
      }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct DailyPerformanceWidget: View {
  @Environment(\.colorScheme) private var colorScheme
  private let points: [Double] = [112, 118, 121, 119, 124, 127, 125, 129, 132]

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 10) {
        Text("Daily Performance")
          .typography(.label, weight: .semibold)

        Chart {
          ForEach(Array(points.enumerated()), id: \.offset) { index, value in
            LineMark(
              x: .value("Time", index),
              y: .value("Value", value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
            
            AreaMark(
              x: .value("Time", index),
              y: .value("Value", value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
              LinearGradient(
                colors: [
                  AppTheme.Colors.tint(for: colorScheme).opacity(0.3),
                  .clear
                ],
                startPoint: .top,
                endPoint: .bottom
              )
            )
          }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 120)

        Text("Intraday trend (mock)")
          .typography(.nano)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct TopMoversWidget: View {
  @Environment(\.colorScheme) private var colorScheme

  private let movers: [Mover] = [
    .init(symbol: "NVDA", changePercent: 4.12),
    .init(symbol: "TSLA", changePercent: 2.84),
    .init(symbol: "META", changePercent: -1.21),
    .init(symbol: "AMD", changePercent: 3.17),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Top Movers")
        .typography(.label, weight: .semibold)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(movers) { mover in
            GlassCard(cornerRadius: 16) {
              VStack(alignment: .leading, spacing: 6) {
                Text(mover.symbol)
                  .typography(.small, weight: .bold)
                Text(mover.changeString)
                  .typography(.label, weight: .semibold)
                  .foregroundStyle(
                    mover.changePercent >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger)
              }
              .frame(width: 100, alignment: .leading)
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct AllocationWidget: View {
  @Environment(\.colorScheme) private var colorScheme

  private var buckets: [AllocationBucket] {
    [
      .init(name: "Tech", percent: 52, color: AppTheme.Colors.tint(for: colorScheme)),
      .init(name: "Index ETFs", percent: 23, color: .indigo),
      .init(name: "Finance", percent: 15, color: .teal),
      .init(name: "Cash", percent: 10, color: .orange),
    ]
  }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 10) {
        Text("Allocation")
          .typography(.label, weight: .semibold)

        ForEach(buckets) { bucket in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(bucket.name)
                .typography(.nano, weight: .semibold)
              Spacer()
              Text("\(bucket.percent)%")
                .typography(.nano)
                .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
              RoundedRectangle(cornerRadius: 4)
                .fill(AppTheme.Colors.tertiaryFill(for: colorScheme))
                .overlay(alignment: .leading) {
                  RoundedRectangle(cornerRadius: 4)
                    .fill(bucket.color)
                    .frame(width: proxy.size.width * CGFloat(bucket.percent) / 100)
                }
            }
            .frame(height: 8)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct PortfolioPosition: Identifiable {
  let symbol: String
  let quantity: Double
  let averageCost: Double
  let marketPrice: Double

  var id: String { symbol }
  var marketValue: Double { quantity * marketPrice }
  var unrealizedPnL: Double { (marketPrice - averageCost) * quantity }
  var unrealizedPnLString: String {
    let sign = unrealizedPnL >= 0 ? "+" : "-"
    return "\(sign)\(abs(unrealizedPnL).currency)"
  }
}

private struct WatchlistItem: Identifiable {
  let symbol: String
  let price: Double
  let changePercent: Double

  var id: String { symbol }
  var changePercentString: String {
    let sign = changePercent >= 0 ? "+" : "-"
    return "\(sign)\(String(format: "%.2f%%", abs(changePercent)))"
  }
}

private struct Mover: Identifiable {
  let symbol: String
  let changePercent: Double

  var id: String { symbol }
  var changeString: String {
    let sign = changePercent >= 0 ? "+" : "-"
    return "\(sign)\(String(format: "%.2f%%", abs(changePercent)))"
  }
}

private struct AllocationBucket: Identifiable {
  let name: String
  let percent: Int
  let color: Color

  var id: String { name }
}

extension Double {
  var currency: String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
  }
}
