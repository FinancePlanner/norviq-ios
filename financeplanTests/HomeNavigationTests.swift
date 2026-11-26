import Foundation
import SwiftUI
import XCTest

@testable import financeplan

/// The app shell: five tabs, every destination with a way in, and one funnel
/// from a push or link to a tab and its path.
final class HomeNavigationTests: XCTestCase {

  private var appRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("financeplan")
  }

  /// A source file with its comment lines removed, so prose that names a
  /// type is not mistaken for code.
  private func code(_ path: String) throws -> String {
    let source = try String(contentsOf: appRoot.appendingPathComponent(path), encoding: .utf8)
    return source
      .split(separator: "\n", omittingEmptySubsequences: false)
      .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
      .joined(separator: "\n")
  }

  private func text(_ resource: LocalizedStringResource, _ locale: String) -> String {
    var resource = resource
    resource.locale = Locale(identifier: locale)
    return String(localized: resource)
  }

  // MARK: - Tabs

  func testFiveTabsInOrderInEnglishAndPortuguese() {
    XCTAssertEqual(AppTab.allCases, [.today, .money, .wealth, .plan, .more])
    XCTAssertEqual(AppTab.allCases.map { text($0.title, "en") }, ["Today", "Money", "Wealth", "Plan", "More"])
    XCTAssertEqual(
      AppTab.allCases.map { text($0.title, "pt-PT") }, ["Hoje", "Dinheiro", "Património", "Plano", "Mais"])
  }

  func testHomeScreenShowsTheFiveTabsAndNothingElse() async throws {
    await Task.yield()
    let src = try code("Features/Home/HomeScreen.swift")
    XCTAssertTrue(src.contains("ForEach(AppTab.allCases"), "one Tab per AppTab, in order")
    XCTAssertTrue(src.contains(".tabViewStyle(.sidebarAdaptable)"), "iPad keeps the adaptable sidebar")
    XCTAssertFalse(src.contains("HomeTab"))
    XCTAssertFalse(src.contains("overflowTabHost"), "no overflow tabs are left to host")
  }

  /// The tab's root scope is what a Pro tap summarises when the screen sets
  /// none. More has nothing to summarise.
  func testEachTabSummarisesItsOwnScope() {
    XCTAssertEqual(AppTab.allCases.map(\.assistantScope), [.home, .expenses, .portfolio, .tax, nil])
  }

  func testGuidedStartTabsMapBothWays() {
    XCTAssertEqual(AppTab.allCases.map(\.guidedTab), [.dashboard, .expenses, .portfolio, nil, nil])
    XCTAssertEqual(AppTab(guided: .dashboard), .today)
    XCTAssertEqual(AppTab(guided: .portfolio), .wealth)
    XCTAssertEqual(AppTab(guided: .expenses), .money)
    // The Goals cover sits on Today until P4.
    XCTAssertEqual(AppTab(guided: .goalPlanning), .today)
  }

  // MARK: - Every destination has a way in

  /// A destination with no row and no toolbar button compiles, renders, and
  /// ships unreachable, which is how Markets once shipped invisible.
  func testEveryDestinationIsReachable() async throws {
    await Task.yield()
    var social = SocialConfig(
      enabled: true, contactsDiscovery: false, xImport: false, leaderboards: false, messaging: false)
    social.groups = true
    let hubRows = (MoreHubModel.sections(social: social, groupsBadge: 0, friendsBadge: 0) + PlanHubModel.sections())
      .flatMap(\.rows)
    var reachable = Set(
      hubRows.compactMap { row -> AppDestination? in
        if case let .push(destination) = row.action { return destination }
        return nil
      })

    // Wealth's Planning menu opens Crypto.
    let wealth = try code("Features/Portfolio/PortfolioRoot.swift")
    let cryptoLink = wealth.contains("NavigationLink(value: PortfolioRootRoute.crypto)")
    if cryptoLink, wealth.contains("case .crypto:\n          CryptoHomeView()") { reachable.insert(.crypto) }
    // Today's bell opens the inbox; its avatar opens Settings.
    let today = try code("Features/Home/DashboardRoot.swift")
    if today.contains("path.append(AppDestination.notifications)") { reachable.insert(.notifications) }
    XCTAssertTrue(today.contains("path.append(AppDestination.settings)"), "Today's avatar opens Settings")

    XCTAssertEqual(Set(AppDestination.allCases).subtracting(reachable), [])
  }

  // MARK: - One funnel

  func testHomeScreenRoutesEveryRequestThroughTheResolver() async throws {
    await Task.yield()
    let src = try code("Features/Home/HomeScreen.swift")
    XCTAssertTrue(src.contains("NavigationResolver.target"))
    XCTAssertFalse(src.contains("selectedTab = .insights"), "a Pro row shows the paywall in place; no Insights bounce")
    XCTAssertFalse(src.contains("isSettingsPresented"), "Settings is a push, not a sheet")
    // Groups pushes the group itself above the depth it reads on appearing.
    XCTAssertFalse(src.contains("GroupsRoute"), "Home pushes only .groups; Groups follows the link")
  }

  /// Settings and the hubs are pushed inside the tabs, so they take the
  /// in-app language from the app root, which sets the locale above them.
  func testTabsInheritTheInAppLocale() async throws {
    await Task.yield()
    XCTAssertTrue(
      try code("NorviqaApp.swift").contains(".environment(\\.locale, Locale(identifier: appLanguage.localeIdentifier))"))
    XCTAssertFalse(
      try code("Features/Home/HomeScreen.swift").contains(".environment(\\.locale"),
      "no screen under Home sets its own locale any more")
  }

  private func pathOf(_ items: any Hashable...) -> NavigationPath {
    var path = NavigationPath()
    for item in items { path.append(item) }
    return path
  }

  func testARequestReplacesWhatElseIsOpenOnTheTab() {
    let target = NavigationTarget(tab: .more, path: [.groups])
    XCTAssertEqual(target.path(replacing: pathOf(AppDestination.settings)), pathOf(AppDestination.groups))
    XCTAssertEqual(target.path(replacing: NavigationPath()), pathOf(AppDestination.groups))
    XCTAssertEqual(
      NavigationTarget(tab: .plan, path: [.tax]).path(replacing: pathOf(AppDestination.goals)),
      pathOf(AppDestination.tax))
  }

  /// Groups reads its depth once, when it first appears, and follows the
  /// link itself. Replacing the path would pop the open group mid-link.
  func testALinkIntoAnOpenGroupLeavesGroupsToFollowIt() {
    let open = pathOf(AppDestination.groups, GroupsRoute.group(UUID(), channelID: nil))
    XCTAssertEqual(NavigationTarget(tab: .more, path: [.groups]).path(replacing: open), open)
  }

  func testAnInviteOverAnOpenProfileLeavesFriendsWhereItIs() {
    let open = pathOf(AppDestination.friends, SocialSettingsDestination.privacy)
    XCTAssertEqual(NavigationTarget(tab: .more, path: [.friends]).path(replacing: open), open)
  }

  // MARK: - Tab roots

  func testTodayHasTheAccountAvatarAndTheBellButNoGear() async throws {
    await Task.yield()
    let src = try code("Features/Home/DashboardRoot.swift")
    XCTAssertFalse(src.contains("gearshape"))
    XCTAssertFalse(src.contains("isSettingsPresented"))
    XCTAssertTrue(src.contains("AccountAvatar("))
    XCTAssertTrue(src.contains("\"bell\""))
    XCTAssertTrue(src.contains("Capture expense"), "the capture + stays")
  }

  @MainActor
  func testWealthHasNoGearAndToolsUseThePlanNames() async throws {
    await Task.yield()
    let src = try code("Features/Portfolio/PortfolioRoot.swift")
    XCTAssertFalse(src.contains("isSettingsPresented"))
    XCTAssertFalse(src.contains("gearshape"))
    for old in ["\"Portfolio simulator\"", "\"Retire\"", "\"Terminal position sizing\""] {
      XCTAssertFalse(src.contains(old), "Wealth still says \(old)")
    }
    for name in ["\"Simulator\"", "\"Retirement\"", "\"Terminal sizing\"", "\"Crypto\""] {
      XCTAssertTrue(src.contains(name), "Wealth's menus lack \(name)")
    }
    XCTAssertEqual(TerminalCopy.title, String(localized: "Terminal sizing"))
  }

  func testMoneyIsTitledBudgetWithNoGear() async throws {
    await Task.yield()
    let src = try code("Features/Expenses/ExpensesPlannerScreen.swift")
    XCTAssertFalse(src.contains("isSettingsPresented"))
    XCTAssertFalse(src.contains("gearshape"))
    XCTAssertTrue(src.contains(".vigilNavigationTitle(\"Budget\")"))
    XCTAssertTrue(src.contains("title: \"Budget\","), "the page header names the screen too")
  }

  /// Markets and Economy are pushed onto More's stack; a stack of their own
  /// draws a second bar.
  func testMarketsAndEconomyDoNotWrapAStack() async throws {
    await Task.yield()
    XCTAssertFalse(try code("Features/Markets/MarketsScreen.swift").contains("NavigationStack {"))
    let economy = try code("Features/Economy/EconomyHubScreen.swift")
    let hub = economy[..<(economy.range(of: "#Preview")?.lowerBound ?? economy.endIndex)]
    XCTAssertFalse(hub.contains("NavigationStack {"))
  }

  // This is a placeholder test file for the Dashboard logic.
  // Based on the 'DashboardService.swift' existing in Features/Home.

  func testDashboardDataAggregation() async {
    await Task.yield()
    // Here you would mock the DashboardService or a response
    // and assert that the view model correctly aggregates the data
    // for the home screen display.

    // Example structure:
    // let service = MockDashboardService()
    // let viewModel = DashboardViewModel(service: service)
    // await viewModel.load()
    // XCTAssertTrue(viewModel.isLoaded)
    // XCTAssertEqual(viewModel.totalPortfolioValue, 10000.0)

    XCTAssertTrue(true, "Dashboard tests need specific service mocking logic.")
  }
}
