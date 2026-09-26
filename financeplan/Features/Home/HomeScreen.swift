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
  @InjectedObservable(\Container.socialStore) private var socialStore
  @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
  let onLogout: () async -> Void
  @State private var selectedTab: HomeTab = .dashboard
  @State private var isSettingsPresented = false
  @State private var isPaywallPresented = false
  @State private var pendingPortfolioOpenSymbol: String?
  @State private var pendingThesisWatchOpen = false
  @State private var pendingAutomationDestination: AutomationNavigationDestination?
  @State private var budgetPlannerViewModel = BudgetPlannerViewModel()
  @Environment(\.scenePhase) private var scenePhase
  @State private var isCapturePresented = false
  /// The assistant opened by a push tap or deep link.
  @State private var assistantLaunch: AssistantLaunch?
  /// Held while one of this screen's own sheets closes; iOS ignores a sheet
  /// presented while another is still up.
  @State private var pendingAssistantLaunch: AssistantLaunch?
  @State private var guided: GuidedStartCoordinator?
  /// An invite link that opened the app, shown once the Friends tab is up.
  @State private var pendingInviteCode: String?

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
    .guidedSpotlight(step: guided?.activeStep, activeTab: guidedTab(for: selectedTab), onSkip: { guided?.skip() })
    .environment(guided)
    .environment(\.norviqReopenGuidedStart, guided.map { coordinator in
      {
        selectedTab = .dashboard
        Task { await coordinator.showMeAround() }
      }
    })
    .task {
      guard guided == nil else { return }
      let coordinator = GuidedStartCoordinator.live()
      guided = coordinator
      await coordinator.refresh()
    }
    .onChange(of: guided?.requestedTab) { _, requested in
      guard let requested else { return }
      selectedTab = homeTab(for: requested)
    }
    // Keep the card's ticks current: a latch can flip on another device, or
    // in a flow no step was open for.
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active, let guided else { return }
      Task { await guided.refresh() }
    }
    .onChange(of: selectedTab) { _, tab in
      guard tab == .dashboard, let guided else { return }
      Task { await guided.refresh() }
    }
  }

  private func guidedTab(for tab: HomeTab) -> GuidedTab? {
    switch tab {
    case .dashboard: .dashboard
    case .portfolio: .portfolio
    case .expenses: .expenses
    default: nil
    }
  }

  private func homeTab(for tab: GuidedTab) -> HomeTab {
    switch tab {
    case .dashboard, .goalPlanning: .dashboard
    case .portfolio: .portfolio
    case .expenses: .expenses
    }
  }

  private var tabView: some View {
    TabView(selection: $selectedTab) {
      ForEach(HomeTab.primaryTabs.filter(isAvailable), id: \.self) { tab in
        Tab(tab.title, systemImage: tab.systemImage, value: tab) {
          root(for: tab)
        }
        .badge(tab == .social ? socialStore.badgeCount : 0)
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
    .sheet(isPresented: $isSettingsPresented, onDismiss: presentPendingAssistant) {
      settingsSheet
    }
    .sheet(isPresented: $isPaywallPresented, onDismiss: presentPendingAssistant) {
      PaywallView(billingManager: billingManager)
    }
    .sheet(item: $assistantLaunch) { launch in
      PersistentAssistantView(conversationID: launch.conversationID)
    }
    .sheet(isPresented: $isCapturePresented, onDismiss: presentPendingAssistant) {
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
    .onChange(of: isSettingsPresented || isPaywallPresented || isCapturePresented || assistantLaunch != nil, initial: true) {
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
    // An app left open across the 1st must land on the new month without a relaunch.
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task { await budgetPlannerViewModel.refreshIfMonthChanged() }
    }
    .onReceive(NotificationCenter.default.publisher(for: .openThesisWatchFromPushNotification)) { _ in
      pendingThesisWatchOpen = true
      selectedTab = .portfolio
    }
    .onReceive(NotificationCenter.default.publisher(for: .openAssistantFromPushNotification)) { notification in
      openAssistant(conversationID: notification.userInfo?["conversationId"] as? String)
    }
    .onReceive(NotificationCenter.default.publisher(for: .openSocialFromPushNotification)) { notification in
      pendingInviteCode = notification.userInfo?["inviteCode"] as? String
      if socialStore.config.enabled { selectedTab = .social }
    }
    // A cold start from an invite link can beat the config fetch.
    .onChange(of: socialStore.config.enabled) { _, enabled in
      if enabled, pendingInviteCode != nil { selectedTab = .social }
    }
    // Loaded up front so the tab badge shows pending requests before the tab is opened.
    .task { await loadSocial() }
  }

  /// Friends stays hidden until the server switches social on: a tab with
  /// nothing behind it is the "incomplete feature" App Review rejects.
  private func isAvailable(_ tab: HomeTab) -> Bool {
    tab != .social || socialStore.config.enabled
  }

  private func loadSocial() async {
    await socialStore.loadConfig()
    guard socialStore.config.enabled else { return }
    await socialStore.load()
  }

  private func openAssistant(conversationID: String?) {
    let launch = AssistantLaunch(conversationID: conversationID)
    guard isSettingsPresented || isPaywallPresented || isCapturePresented else {
      assistantLaunch = launch
      return
    }
    pendingAssistantLaunch = launch
    isSettingsPresented = false
    isPaywallPresented = false
    isCapturePresented = false
  }

  private func presentPendingAssistant() {
    guard let launch = pendingAssistantLaunch else { return }
    pendingAssistantLaunch = nil
    assistantLaunch = launch
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
    case .social:
      SocialRoot(pendingInviteCode: $pendingInviteCode)
        .accessibilityIdentifier("tab.social")
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

private struct AssistantLaunch: Identifiable {
  let id = UUID()
  let conversationID: String?
}
