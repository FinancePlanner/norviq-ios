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
  @InjectedObservable(\Container.quickAssistantCoordinator) private var quickAssistant
  @InjectedObservable(\Container.socialStore) private var socialStore
  @InjectedObservable(\Container.boardsViewerStore) private var boardsViewer
  @InjectedObservable(\Container.groupsStore) private var groupsStore
  @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.english.rawValue
  let onLogout: () async -> Void
  @State private var selectedTab: AppTab = .today
  /// The stacks a request can push onto. Money's and Wealth's roots keep a
  /// plain stack: no request lands above them.
  @State private var todayPath = NavigationPath()
  @State private var planPath = NavigationPath()
  @State private var morePath = NavigationPath()
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
  /// An invite link that opened the app, shown once Friends is up.
  @State private var pendingInviteCode: String?
  /// New unlocks waiting to be celebrated, and the screen they lead to.
  @State private var unlockCoordinator = Container.shared.achievementUnlockCoordinator()
  @State private var isAchievementsPresented = false
  /// A Friends section a push asked for (`feed`), consumed by Friends.
  @State private var pendingSocialSection: String?
  /// The AI summary a tap on Q opened.
  @State private var summaryScope: AIViewScope?

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
        .qAccessory(
          coordinator: quickAssistant,
          isSummaryAvailable: isQTapASummary,
          onTap: { openQ(isHold: false) },
          onHold: { openQ(isHold: true) }
        )
    }
    .appAnimation(AppMotion.structural, value: billingManager.shouldShowTrialEndedBanner)
    .guidedSpotlight(step: guided?.activeStep, activeTab: selectedTab.guidedTab, onSkip: { guided?.skip() })
    // After the spotlight, or its scrim draws over the card.
    .overlay {
      QuickAssistantOverlay(
        onOpenInQ: { openAssistant(conversationID: $0) },
        onPaywall: { isPaywallPresented = true }
      )
    }
    .aiSummaryPresentation(scope: $summaryScope)
    // A guided step hides Q, as on the web; the bubble sits where Q does.
    .onChange(of: guided?.activeStep != nil, initial: true) { _, active in
      quickAssistant.setGuidedStepActive(active)
    }
    .onDisappear { quickAssistant.setGuidedStepActive(false) }
    .environment(guided)
    .environment(\.norviqReopenGuidedStart, guided.map { coordinator in
      // The tour starts on Today's root, whichever stack Settings was on.
      {
        selectedTab = .today
        todayPath = NavigationPath()
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
      selectedTab = AppTab(guided: requested)
    }
    // Keep the card's ticks current: a latch can flip on another device, or
    // in a flow no step was open for.
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active, let guided else { return }
      Task { await guided.refresh() }
    }
    .onChange(of: selectedTab) { _, tab in
      guard tab == .today, let guided else { return }
      Task { await guided.refresh() }
    }
    // Kept off `tabView`, whose modifier chain is at the type checker's limit.
    .onReceive(NotificationCenter.default.publisher(for: .openMarketBriefFromPushNotification)) { notification in
      openMarketBrief(notification)
    }
    .onReceive(NotificationCenter.default.publisher(for: .openGroupsFromPushNotification)) { notification in
      openGroups(notification)
    }
    // A cold start from a group link or push can beat the config fetch.
    .onChange(of: groupsEnabled) { _, enabled in
      if enabled, groupsStore.pendingLink != nil { navigate(to: .groups) }
    }
    // Live while the app is in front; pushes cover the background.
    .task(id: groupsEnabled && scenePhase == .active) {
      guard groupsEnabled, scenePhase == .active else {
        groupsStore.stopRealtime()
        return
      }
      groupsStore.startRealtime()
    }
  }

  private var groupsEnabled: Bool { socialStore.config.groupsEnabled }

  /// Lands a push, link or hub row: its tab, and that tab's path. Side
  /// effects (a pending symbol or link, the brief router) stay with the caller.
  private func navigate(to request: NavigationRequest) {
    guard
      let target = NavigationResolver.target(
        for: request, groupsEnabled: groupsEnabled, socialEnabled: socialStore.config.enabled)
    else { return }
    selectedTab = target.tab
    switch target.tab {
    case .today: todayPath = target.path(replacing: todayPath)
    case .plan: planPath = target.path(replacing: planPath)
    case .more: morePath = target.path(replacing: morePath)
    case .money, .wealth: assert(target.path.isEmpty, "\(target.tab)'s root has no path to push onto")
    }
  }

  /// A group push or link: Groups under More, which opens what it names. Only
  /// Groups is pushed; it reads its depth when it first appears, then follows
  /// the link itself.
  private func openGroups(_ notification: Notification) {
    groupsStore.pendingLink = notification.userInfo?["link"] as? GroupDeepLink
    navigate(to: .groups)
  }

  /// More carries what Groups and Friends have waiting.
  private func badge(for tab: AppTab) -> Int {
    tab == .more ? groupsStore.badgeCount + socialStore.badgeCount : 0
  }

  /// A brief push or link: Today, with the card on that brief.
  private func openMarketBrief(_ notification: Notification) {
    openMarketBrief(
      MarketBriefDeepLink.ref(
        slot: notification.userInfo?["slot"] as? String,
        date: notification.userInfo?["tradingDate"] as? String
      ))
  }

  /// `nil` is the latest brief.
  private func openMarketBrief(_ ref: MarketBriefRef?) {
    navigate(to: .marketBrief)
    Container.shared.marketBriefRouter().open(ref)
  }

  /// A More row that lives on another tab.
  private func openFromHub(_ request: NavigationRequest) {
    if request == .marketBrief {
      openMarketBrief(nil)
    } else {
      navigate(to: request)
    }
  }

  /// Summaries are server-driven rather than a raw `isPro` read, so they can
  /// be turned off for a user without an App Store release.
  /// `isFeatureAvailable` already falls back to `isPro` when the server says
  /// nothing.
  private func qRoute(isHold: Bool) -> QEntryRoute {
    QEntryRoute.resolve(
      hasSummaries: billingManager.isFeatureAvailable("ai_insights"),
      screenScope: quickAssistant.currentScope,
      tabScope: selectedTab.assistantScope,
      isHold: isHold
    )
  }

  private var isQTapASummary: Bool {
    if case .summary = qRoute(isHold: false) { return true }
    return false
  }

  private func openQ(isHold: Bool) {
    switch qRoute(isHold: isHold) {
    case let .summary(scope): summaryScope = scope
    case let .card(scope): quickAssistant.present(scope: scope)
    }
  }

  private var tabView: some View {
    TabView(selection: $selectedTab) {
      ForEach(AppTab.allCases, id: \.self) { tab in
        Tab(value: tab) {
          root(for: tab).qEntryPoint()
        } label: {
          Label { Text(tab.title) } icon: { Image(systemName: tab.systemImage) }
        }
        .badge(badge(for: tab))
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
    .sheet(isPresented: $isPaywallPresented, onDismiss: presentPendingAssistant) {
      PaywallView(billingManager: billingManager)
    }
    .sheet(item: $assistantLaunch) { launch in
      PersistentAssistantView(conversationID: launch.conversationID)
    }
    .modifier(
      AchievementsPresentation(
        coordinator: unlockCoordinator,
        isAchievementsPresented: $isAchievementsPresented,
        isCovered: isSheetOrCardCovering,
        isEnabled: socialStore.config.achievements
      )
    )
    .sheet(isPresented: $isCapturePresented, onDismiss: presentPendingAssistant) {
      HomeQuickExpenseSheet(defaultSharePercent: budgetPlannerViewModel.seededUserSharePercent) { draft in
        await handleCaptureSave(draft)
      }
    }
    // Never let the review sheet land on top of a paywall or capture sheet.
    .onChange(of: isSheetOrCardCovering, initial: true) {
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
      navigate(to: .tax)
    }
    .onReceive(NotificationCenter.default.publisher(for: .openBudgetFromPushNotification)) { _ in
      navigate(to: .budget)
      Task { await budgetPlannerViewModel.load(force: true) }
    }
    // An app left open across the 1st must land on the new month without a relaunch.
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task { await budgetPlannerViewModel.refreshIfMonthChanged() }
    }
    .onReceive(NotificationCenter.default.publisher(for: .openThesisWatchFromPushNotification)) { _ in
      pendingThesisWatchOpen = true
      navigate(to: .thesisWatch)
    }
    .onReceive(NotificationCenter.default.publisher(for: .openAssistantFromPushNotification)) { notification in
      openAssistant(conversationID: notification.userInfo?["conversationId"] as? String)
    }
    .onReceive(NotificationCenter.default.publisher(for: .openSocialFromPushNotification)) { notification in
      pendingInviteCode = notification.userInfo?["inviteCode"] as? String
      pendingSocialSection = notification.userInfo?[AchievementPushDestination.socialSectionKey] as? String
      navigate(to: .social(inviteCode: pendingInviteCode, section: pendingSocialSection))
    }
    .onReceive(NotificationCenter.default.publisher(for: .openBoardPostFromPushNotification)) { notification in
      guard let raw = notification.userInfo?["postId"] as? String, let postID = UUID(uuidString: raw) else { return }
      navigate(to: .boardPost)
      boardsViewer.open(postID: postID)
    }
    // A cold start from an invite link can beat the config fetch.
    .onChange(of: socialStore.config.enabled) { _, enabled in
      if enabled, pendingInviteCode != nil {
        navigate(to: .social(inviteCode: pendingInviteCode, section: pendingSocialSection))
      }
    }
    // Loaded up front so the tab badge shows pending requests before the tab is opened.
    .task { await loadSocial() }
  }

  private func loadSocial() async {
    await socialStore.loadConfig()
    await unlockCoordinator.checkForUnlocks()
    guard socialStore.config.enabled else { return }
    await socialStore.load()
    if groupsEnabled { await groupsStore.load() }
  }

  private var isSheetOrCardCovering: Bool {
    isPaywallPresented || isCapturePresented || assistantLaunch != nil
      || quickAssistant.isPresented || summaryScope != nil
  }

  private func openAssistant(conversationID: String?) {
    let launch = AssistantLaunch(conversationID: conversationID)
    guard isPaywallPresented || isCapturePresented else {
      assistantLaunch = launch
      return
    }
    pendingAssistantLaunch = launch
    isPaywallPresented = false
    isCapturePresented = false
  }

  private func presentPendingAssistant() {
    guard let launch = pendingAssistantLaunch else { return }
    pendingAssistantLaunch = nil
    assistantLaunch = launch
  }

  @ViewBuilder
  private func root(for tab: AppTab) -> some View {
    switch tab {
    case .today:
      DashboardRoot(
        selectedTab: $selectedTab,
        path: $todayPath,
        isCapturePresented: $isCapturePresented,
        budgetStore: budgetPlannerViewModel
      )
    case .money:
      ExpensesPlannerScreen(viewModel: budgetPlannerViewModel)
    case .wealth:
      PortfolioRoot(
        pendingOpenSymbol: $pendingPortfolioOpenSymbol,
        pendingThesisWatchOpen: $pendingThesisWatchOpen,
        pendingAutomationDestination: $pendingAutomationDestination
      )
    case .plan:
      PlanHubScreen(path: $planPath)
    case .more:
      MoreHubScreen(
        path: $morePath,
        pendingInviteCode: $pendingInviteCode,
        pendingSocialSection: $pendingSocialSection,
        onSelectTab: { _, request in openFromHub(request) }
      )
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
    navigate(to: .stock(symbol: symbol))
  }

  private func openPortfolioTab(_ notification: Notification) {
    pendingPortfolioOpenSymbol = nil
    let id = (notification.userInfo?["automation_id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    let destination = notification.userInfo?["automation_destination"] as? String
    switch destination {
    case "watchlist_screen": pendingAutomationDestination = .smartScreen(id)
    case "rebalancing": pendingAutomationDestination = .rebalancing(id)
    default: pendingAutomationDestination = nil
    }
    navigate(to: .portfolio(automation: destination))
  }
}

private struct AssistantLaunch: Identifiable {
  let id = UUID()
  let conversationID: String?
}
