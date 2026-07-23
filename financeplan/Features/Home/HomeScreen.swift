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
  @State private var tabBarChrome = TabBarChromeController()
  @State private var isMorePresented = false
  @State private var isCapturePresented = false

  private var appLanguage: AppLanguage {
    AppLanguage.from(appLanguageRawValue)
  }

  private var chromeItems: [RevolutTabBar.Item] {
    [
      .init(kind: .tab(.dashboard), title: HomeTab.dashboard.title, systemImage: HomeTab.dashboard.systemImage),
      .init(kind: .tab(.portfolio), title: HomeTab.portfolio.title, systemImage: HomeTab.portfolio.systemImage),
      .init(kind: .tab(.expenses), title: HomeTab.expenses.title, systemImage: HomeTab.expenses.systemImage),
      .init(kind: .tab(.crypto), title: HomeTab.crypto.title, systemImage: HomeTab.crypto.systemImage),
      .init(kind: .more, title: String(localized: "More"), systemImage: "ellipsis"),
    ]
  }

  private var moreTabs: Set<HomeTab> {
    [.economy, .reports, .tax, .insights]
  }

  var body: some View {
    VStack(spacing: 0) {
      if billingManager.shouldShowTrialEndedBanner {
        TrialEndedBanner(onSubscribe: { isPaywallPresented = true })
          .padding(.top, 8)
          .padding(.bottom, 4)
          .transition(AppTransition.move(edge: .top, reduceMotion: reduceMotion))
      }

      ZStack(alignment: .bottom) {
        tabView

        RevolutTabBar(
          selection: $selectedTab,
          items: chromeItems,
          moreTabs: moreTabs,
          showsCapture: true,
          isMinimized: tabBarChrome.isMinimized,
          onSelect: { tab in
            tabBarChrome.expand()
            selectedTab = tab
          },
          onMore: {
            tabBarChrome.expand()
            isMorePresented = true
          },
          onCapture: {
            tabBarChrome.expand()
            isCapturePresented = true
          }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
      }
    }
    .environment(\.tabBarChrome, tabBarChrome)
    .appAnimation(AppMotion.structural, value: billingManager.shouldShowTrialEndedBanner)
  }

  private var tabView: some View {
    TabView(selection: $selectedTab) {
      Tab(HomeTab.dashboard.title, systemImage: HomeTab.dashboard.systemImage, value: .dashboard) {
        DashboardRoot(
          selectedTab: $selectedTab,
          isSettingsPresented: $isSettingsPresented,
          budgetStore: budgetPlannerViewModel
        )
      }

      Tab(HomeTab.portfolio.title, systemImage: HomeTab.portfolio.systemImage, value: .portfolio) {
        PortfolioRoot(
          isSettingsPresented: $isSettingsPresented,
          pendingOpenSymbol: $pendingPortfolioOpenSymbol,
          pendingAutomationDestination: $pendingAutomationDestination
        )
      }

      Tab(HomeTab.economy.title, systemImage: HomeTab.economy.systemImage, value: .economy) {
        EconomyHubScreen()
          .accessibilityIdentifier("tab.economy")
      }

      Tab(HomeTab.crypto.title, systemImage: HomeTab.crypto.systemImage, value: .crypto) {
        CryptoHomeView(isSettingsPresented: $isSettingsPresented)
          .accessibilityIdentifier("tab.crypto")
      }

      Tab(HomeTab.expenses.title, systemImage: HomeTab.expenses.systemImage, value: .expenses) {
        ExpensesPlannerScreen(isSettingsPresented: $isSettingsPresented, viewModel: budgetPlannerViewModel)
          .accessibilityIdentifier("tab.expenses")
      }

      Tab(HomeTab.reports.title, systemImage: HomeTab.reports.systemImage, value: .reports) {
        ExpensesComparisonScreen()
          .accessibilityIdentifier("tab.reports")
      }

      Tab(HomeTab.tax.title, systemImage: HomeTab.tax.systemImage, value: .tax) {
        TaxDashboardScreen()
          .accessibilityIdentifier("tab.tax")
      }

      Tab(HomeTab.insights.title, systemImage: HomeTab.insights.systemImage, value: .insights) {
        InsightsScreen()
          .accessibilityIdentifier("tab.insights")
      }
    }
    .id(appLanguage.rawValue)
    .tint(AppTheme.Colors.tint(for: colorScheme))
    .toolbar(.hidden, for: .tabBar)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      Color.clear.frame(height: tabBarChrome.isMinimized ? 70 : 98)
    }
    .sheet(isPresented: $isSettingsPresented) {
      settingsSheet
    }
    .sheet(isPresented: $isPaywallPresented) {
      PaywallView(billingManager: billingManager)
    }
    .sheet(isPresented: $isMorePresented) {
      moreSheet
    }
    .sheet(isPresented: $isCapturePresented) {
      HomeQuickExpenseSheet { draft in
        await handleCaptureSave(draft)
      }
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

  private var moreSheet: some View {
    NavigationStack {
      List {
        ForEach([HomeTab.economy, .reports, .tax, .insights], id: \.self) { tab in
          Button {
            isMorePresented = false
            selectedTab = tab
          } label: {
            Label(tab.title, systemImage: tab.systemImage)
          }
          .accessibilityIdentifier("tabBar.more.\(tab)")
        }
      }
      .navigationTitle(String(localized: "More"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "Done")) {
            isMorePresented = false
          }
        }
      }
    }
    .presentationDetents([.medium])
  }

  private func handleCaptureSave(_ draft: HomeQuickExpenseDraft) async -> String? {
    let didSave = await budgetPlannerViewModel.recordExpenseAndWait(
      BudgetActivityDraft(
        title: draft.title,
        amount: draft.amount,
        pillar: draft.pillar,
        occurredOn: draft.occurredOn,
        linkedPlanItemID: nil,
        splitMode: draft.splitMode,
        userSharePercent: draft.userSharePercent,
        receiptMetadata: draft.receiptMetadata
      )
    )
    guard didSave else {
      return budgetPlannerViewModel.errorMessage ?? String(localized: "Could not save expense. Please try again.")
    }
    return nil
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
