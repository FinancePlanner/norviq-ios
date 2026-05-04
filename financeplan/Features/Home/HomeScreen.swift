import Charts
import Foundation
import Observation
import OSLog
import StoreKit
import SwiftUI
import StockPlanShared
import Factory

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
      Tab(HomeTab.dashboard.title, systemImage: "house", value: .dashboard) {
        DashboardRoot(
          selectedTab: $selectedTab,
          isSettingsPresented: $isSettingsPresented,
          budgetStore: budgetPlannerViewModel
        )
      }

      Tab(HomeTab.portfolio.title, systemImage: "chart.line.uptrend.xyaxis", value: .portfolio) {
        PortfolioRoot(
          isSettingsPresented: $isSettingsPresented,
          pendingOpenSymbol: $pendingPortfolioOpenSymbol
        )
      }

      Tab(HomeTab.expenses.title, systemImage: "creditcard", value: .expenses) {
        ExpensesPlannerScreen(isSettingsPresented: $isSettingsPresented, viewModel: budgetPlannerViewModel)
          .accessibilityIdentifier("tab.expenses")
      }

      Tab(HomeTab.reports.title, systemImage: "chart.bar.xaxis", value: .reports) {
        ExpensesComparisonScreen()
          .accessibilityIdentifier("tab.reports")
      }
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
