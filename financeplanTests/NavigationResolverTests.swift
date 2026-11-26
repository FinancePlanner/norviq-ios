import XCTest

@testable import financeplan

/// The one table that decides which tab, and which pushed path, each
/// navigation request lands on.
final class NavigationResolverTests: XCTestCase {

  private func target(
    _ request: NavigationRequest, groups: Bool = true, social: Bool = true
  ) -> NavigationTarget? {
    NavigationResolver.target(for: request, groupsEnabled: groups, socialEnabled: social)
  }

  func testFiveTabsInOrderWithEnglishTitles() {
    XCTAssertEqual(AppTab.allCases, [.today, .money, .wealth, .plan, .more])
    XCTAssertEqual(
      AppTab.allCases.map { tab -> String in
        var title = tab.title
        title.locale = Locale(identifier: "en")
        return String(localized: title)
      },
      ["Today", "Money", "Wealth", "Plan", "More"])
    XCTAssertEqual(
      AppTab.allCases.map(\.systemImage),
      ["sun.max", "creditcard", "chart.line.uptrend.xyaxis", "target", "ellipsis.circle"])
  }

  func testWealthRoots() {
    let expected = NavigationTarget(tab: .wealth, path: [])
    XCTAssertEqual(target(.stock(symbol: "AAPL")), expected)
    XCTAssertEqual(target(.portfolio(automation: nil)), expected)
    XCTAssertEqual(target(.portfolio(automation: "rebalance")), expected)
    XCTAssertEqual(target(.thesisWatch), expected)
  }

  func testCryptoPushesUnderWealth() {
    XCTAssertEqual(target(.crypto), NavigationTarget(tab: .wealth, path: [.crypto]))
  }

  func testBudgetIsMoney() {
    XCTAssertEqual(target(.budget), NavigationTarget(tab: .money, path: []))
  }

  func testTaxIsUnderPlan() {
    XCTAssertEqual(target(.tax), NavigationTarget(tab: .plan, path: [.tax]))
  }

  func testMarketBriefIsToday() {
    XCTAssertEqual(target(.marketBrief), NavigationTarget(tab: .today, path: []))
  }

  func testSocialIsFriendsUnderMore() {
    let expected = NavigationTarget(tab: .more, path: [.friends])
    XCTAssertEqual(target(.social(inviteCode: nil, section: nil)), expected)
    XCTAssertEqual(target(.social(inviteCode: "ABC", section: "requests")), expected)
  }

  func testSocialIsNilWhenSocialDisabled() {
    XCTAssertNil(target(.social(inviteCode: nil, section: nil), social: false))
  }

  func testGroupsAreUnderMoreOrNilWhenDisabled() {
    XCTAssertEqual(target(.groups), NavigationTarget(tab: .more, path: [.groups]))
    XCTAssertNil(target(.groups, groups: false))
  }

  func testMoreHubDestinations() {
    XCTAssertEqual(target(.boardPost), NavigationTarget(tab: .more, path: [.boards]))
    XCTAssertEqual(target(.reports), NavigationTarget(tab: .more, path: [.reports]))
    XCTAssertEqual(target(.insights), NavigationTarget(tab: .more, path: [.insights]))
    XCTAssertEqual(target(.settings), NavigationTarget(tab: .more, path: [.settings]))
  }

  func testDisabledFlagsDoNotAffectOtherRequests() {
    XCTAssertEqual(
      target(.boardPost, groups: false, social: false),
      NavigationTarget(tab: .more, path: [.boards]))
  }
}
