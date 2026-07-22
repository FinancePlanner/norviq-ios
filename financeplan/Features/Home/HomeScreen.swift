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
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme
  @InjectedObservable(\Container.billingManager) private var billingManager
  @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
  let onLogout: () async -> Void
  @State private var selectedTab: HomeTab = .dashboard
  @State private var isSettingsPresented = false
  @State private var isPaywallPresented = false
  @State private var pendingPortfolioOpenSymbol: String?
  @State private var pendingAutomationDestination: AutomationNavigationDestination?
  @State private var budgetPlannerViewModel = BudgetPlannerViewModel()

  private var appLanguage: AppLanguage {
    AppLanguage.from(appLanguageRawValue)
  }

  var body: some View {
    VStack(spacing: 0) {
      if billingManager.shouldShowTrialEndedBanner {
        TrialEndedBanner(onSubscribe: { isPaywallPresented = true })
          .padding(.top, 8)
          .padding(.bottom, 4)
          .transition(AppTransition.move(edge: .top, reduceMotion: reduceMotion))
      }

      tabView
    }
    .appAnimation(AppMotion.structural, value: billingManager.shouldShowTrialEndedBanner)
  }

  private var tabView: some View {
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
          pendingOpenSymbol: $pendingPortfolioOpenSymbol,
          pendingAutomationDestination: $pendingAutomationDestination
        )
      }

      Tab(HomeTab.economy.title, systemImage: "chart.bar.xaxis", value: .economy) {
        EconomyHubScreen()
          .accessibilityIdentifier("tab.economy")
      }

      Tab(HomeTab.crypto.title, systemImage: "bitcoinsign.circle", value: .crypto) {
        CryptoHomeView(isSettingsPresented: $isSettingsPresented)
          .accessibilityIdentifier("tab.crypto")
      }

      Tab(HomeTab.expenses.title, systemImage: "creditcard", value: .expenses) {
        ExpensesPlannerScreen(isSettingsPresented: $isSettingsPresented, viewModel: budgetPlannerViewModel)
          .accessibilityIdentifier("tab.expenses")
      }

      Tab(HomeTab.reports.title, systemImage: "chart.bar.doc.horizontal", value: .reports) {
        ExpensesComparisonScreen()
          .accessibilityIdentifier("tab.reports")
      }

      Tab(HomeTab.tax.title, systemImage: "building.columns", value: .tax) {
        TaxDashboardScreen()
          .accessibilityIdentifier("tab.tax")
      }

      Tab(HomeTab.insights.title, systemImage: "sparkles", value: .insights) {
        InsightsScreen()
          .accessibilityIdentifier("tab.insights")
      }
    }
    .id(appLanguage.rawValue)
    .tint(AppTheme.Colors.tint(for: colorScheme))
    .toolbarBackground(.visible, for: .tabBar)
    .toolbarBackground(AppTheme.Colors.tabBarBackground(for: colorScheme), for: .tabBar)
    .sheet(isPresented: $isSettingsPresented) {
      settingsSheet
    }
    .sheet(isPresented: $isPaywallPresented) {
      PaywallView(billingManager: billingManager)
    }
    .onChange(of: selectedTab) { _, newValue in
      guard newValue == .insights, !billingManager.isPro else { return }
      selectedTab = .dashboard
      isPaywallPresented = true
    }
    .onReceive(NotificationCenter.default.publisher(for: .openStockFromPushNotification)) { notification in
      handleOpenStockNotification(notification)
    }
    .onReceive(NotificationCenter.default.publisher(for: .openPortfolioFromPushNotification)) { notification in
      openPortfolioTab(notification)
    }
    .onReceive(NotificationCenter.default.publisher(for: .openTaxFromPushNotification)) { _ in
      selectedTab = .tax
    }
    .onReceive(NotificationCenter.default.publisher(for: .openBudgetFromPushNotification)) { _ in
      selectedTab = .expenses
      Task { await budgetPlannerViewModel.load(force: true) }
    }
    .onReceive(NotificationCenter.default.publisher(for: .openThesisWatchFromPushNotification)) { _ in
      selectedTab = .portfolio
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

  private func openPortfolioTab(_ notification: Notification) {
    pendingPortfolioOpenSymbol = nil
    let id = (notification.userInfo?["automation_id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    switch notification.userInfo?["automation_destination"] as? String {
    case "watchlist_screen": pendingAutomationDestination = .smartScreen(id)
    case "rebalancing": pendingAutomationDestination = .rebalancing(id)
    default: pendingAutomationDestination = nil
    }
    selectedTab = .portfolio
  }
}
