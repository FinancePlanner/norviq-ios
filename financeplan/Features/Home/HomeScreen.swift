import Charts
import Foundation
import Observation
import OSLog
import SwiftUI
import UIKit
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
  @State private var pendingThesisWatchOpen = false
  @State private var pendingAutomationDestination: AutomationNavigationDestination?
  @State private var budgetPlannerViewModel = BudgetPlannerViewModel()
  @State private var isCapturePresented = false

  init(onLogout: @escaping () async -> Void) {
    self.onLogout = onLogout
  }

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
      ForEach(HomeTab.primaryTabs, id: \.self) { tab in
        Tab(tab.title, systemImage: tab.systemImage, value: tab) {
          root(for: tab)
        }
      }
      ForEach(HomeTab.moreMenuTabs, id: \.self) { tab in
        Tab(tab.title, systemImage: tab.systemImage, value: tab) {
          root(for: tab)
        }
      }
    }
    .id(appLanguage.rawValue)
    .tint(AppTheme.Colors.tint)
    // Adapts to a sidebar on iPad, where a 361pt capsule centred in a 1024pt
    // canvas never made sense. The manual safeAreaInset that reserved space for
    // that capsule is gone with it: it was a hardcoded 70/98pt that did not grow
    // with Dynamic Type, and it animated during scroll, shifting content under
    // the finger.
    .tabViewStyle(.sidebarAdaptable)
    .reviewPromptPresenter()
    .sheet(isPresented: $isSettingsPresented) {
      settingsSheet
    }
    .sheet(isPresented: $isPaywallPresented) {
      PaywallView(billingManager: billingManager)
    }
    .sheet(isPresented: $isCapturePresented) {
      HomeQuickExpenseSheet(defaultSharePercent: budgetPlannerViewModel.seededUserSharePercent) { draft in
        await handleCaptureSave(draft)
      }
    }
    .onChange(of: selectedTab) { _, newValue in
      guard newValue == .insights, !billingManager.isPro else { return }
      selectedTab = .dashboard
      isPaywallPresented = true
    }
    // Never let the review sheet land on top of a settings, paywall, or capture sheet.
    .onChange(of: isSettingsPresented || isPaywallPresented || isCapturePresented, initial: true) {
      _, isCovered in
      Container.shared.reviewPromptCoordinator().setContextEligible(!isCovered)
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
      pendingThesisWatchOpen = true
      selectedTab = .portfolio
    }
  }

  private var settingsSheet: some View {
    UserProfileView()
      .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
  }

  @ViewBuilder
  private func root(for tab: HomeTab) -> some View {
    switch tab {
    case .dashboard:
      DashboardRoot(
        selectedTab: $selectedTab,
        isSettingsPresented: $isSettingsPresented,
        isCapturePresented: $isCapturePresented,
        budgetStore: budgetPlannerViewModel
      )
    case .portfolio:
      PortfolioRoot(
        isSettingsPresented: $isSettingsPresented,
        pendingOpenSymbol: $pendingPortfolioOpenSymbol,
        pendingThesisWatchOpen: $pendingThesisWatchOpen,
        pendingAutomationDestination: $pendingAutomationDestination
      )
    case .markets:
      overflowTabHost {
        MarketsScreen()
      }
      .accessibilityIdentifier("tab.markets")
    case .economy:
      overflowTabHost {
        EconomyHubScreen()
      }
      .accessibilityIdentifier("tab.economy")
    case .crypto:
      CryptoHomeView(isSettingsPresented: $isSettingsPresented)
        .accessibilityIdentifier("tab.crypto")
    case .expenses:
      ExpensesPlannerScreen(isSettingsPresented: $isSettingsPresented, viewModel: budgetPlannerViewModel)
        .accessibilityIdentifier("tab.expenses")
    case .reports:
      ExpensesComparisonScreen()
        .accessibilityIdentifier("tab.reports")
    case .tax:
      TaxDashboardScreen()
        .accessibilityIdentifier("tab.tax")
    case .insights:
      InsightsScreen()
        .accessibilityIdentifier("tab.insights")
    }
  }

  /// iPhone More already pushes overflow tabs onto a UINavigationController.
  /// Nesting another NavigationStack is what produced two bars (back on one,
  /// AI on the other). iPad sidebar has no such push, so it still needs a stack
  /// for NavigationLink / navigationDestination.
  @ViewBuilder
  private func overflowTabHost<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    if UIDevice.current.userInterfaceIdiom == .pad {
      NavigationStack { content() }
    } else {
      content()
    }
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
