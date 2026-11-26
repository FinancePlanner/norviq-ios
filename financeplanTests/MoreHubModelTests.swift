import XCTest

@testable import financeplan

/// The rows of the More and Plan hubs: names from the destination table,
/// gates, Pro marks, and what a tap does.
final class MoreHubModelTests: XCTestCase {

  private let english = Locale(identifier: "en")

  private func config(enabled: Bool, groups: Bool) -> SocialConfig {
    var config = SocialConfig(
      enabled: enabled, contactsDiscovery: false, xImport: false, leaderboards: false, messaging: false
    )
    config.groups = groups
    return config
  }

  private func text(_ resource: LocalizedStringResource) -> String {
    var resource = resource
    resource.locale = english
    return String(localized: resource)
  }

  private func titles(_ section: HubSection) -> [String] {
    section.rows.map { text($0.title) }
  }

  private func more(enabled: Bool = true, groups: Bool = true, badge: Int = 0) -> [HubSection] {
    MoreHubModel.sections(social: config(enabled: enabled, groups: groups), groupsBadge: badge, locale: english)
  }

  private func row(_ id: String, in sections: [HubSection]) -> HubRow? {
    sections.flatMap(\.rows).first { $0.id == id }
  }

  // MARK: - More

  func testMoreWithEveryFlagOn() {
    let sections = more()
    XCTAssertEqual(sections.map { text($0.title) }, ["Intelligence", "Community", "Account"])
    XCTAssertEqual(
      titles(sections[0]), ["Market brief", "Markets", "Economy", "Insights", "Reports", "Chart builder"])
    XCTAssertEqual(titles(sections[1]), ["Groups", "Friends", "Boards"])
    XCTAssertEqual(titles(sections[2]), ["Brokers and imports", "Settings"])
  }

  func testOnlyInsightsIsProInMore() {
    let pro = more().flatMap(\.rows).filter(\.isPro).map(\.id)
    XCTAssertEqual(pro, ["insights"])
  }

  func testMoreActions() {
    let sections = more()
    XCTAssertEqual(row("marketBrief", in: sections)?.action, .selectTab(.today, .marketBrief))
    XCTAssertEqual(
      sections.flatMap(\.rows).dropFirst().map(\.action),
      [
        .push(.markets), .push(.economy), .push(.insights), .push(.reports), .push(.chartBuilder),
        .push(.groups), .push(.friends), .push(.boards),
        .push(.brokers), .push(.settings)
      ])
  }

  func testSocialOffLeavesBoardsOnly() {
    XCTAssertEqual(titles(more(enabled: false)[1]), ["Boards"])
    // Groups need the social graph: the groups switch alone shows nothing.
    XCTAssertEqual(titles(more(enabled: false, groups: true)[1]), ["Boards"])
  }

  func testGroupsOffKeepsFriends() {
    XCTAssertEqual(titles(more(groups: false)[1]), ["Friends", "Boards"])
  }

  func testGroupsBadgeIsTheRowValue() {
    XCTAssertEqual(row("groups", in: more(badge: 2))?.value, "2 new")
    XCTAssertEqual(row("groups", in: more(badge: 1))?.value, "1 new")
    XCTAssertNil(row("groups", in: more(badge: 0))?.value)
  }

  func testGroupsBadgeIsAPluralInPortuguese() {
    let portuguese = Locale(identifier: "pt-PT")
    let social = config(enabled: true, groups: true)
    XCTAssertEqual(
      row("groups", in: MoreHubModel.sections(social: social, groupsBadge: 1, locale: portuguese))?.value, "1 nova")
    XCTAssertEqual(
      row("groups", in: MoreHubModel.sections(social: social, groupsBadge: 3, locale: portuguese))?.value, "3 novas")
  }

  func testOtherMoreRowsHaveNoValue() {
    XCTAssertEqual(more(badge: 2).flatMap(\.rows).compactMap(\.value), ["2 new"])
  }

  // MARK: - Plan

  func testPlanSectionsAndRows() {
    let sections = PlanHubModel.sections()
    XCTAssertEqual(sections.map { text($0.title) }, ["Goals", "Your future", "Tax"])
    XCTAssertEqual(titles(sections[0]), ["Goals"])
    XCTAssertEqual(
      titles(sections[1]), ["Net worth forecast", "Retirement", "Scenarios", "Simulator", "Grow", "Tools"])
    XCTAssertEqual(titles(sections[2]), ["Tax strategy", "Terminal sizing"])
  }

  func testPlanProRows() {
    let pro = PlanHubModel.sections().flatMap(\.rows).filter(\.isPro).map(\.id)
    XCTAssertEqual(pro, ["netWorthForecast", "scenarios"])
  }

  func testPlanRowsPush() {
    XCTAssertEqual(
      PlanHubModel.sections().flatMap(\.rows).map(\.action),
      [
        .push(.goals),
        .push(.netWorthForecast), .push(.retirement), .push(.scenarios), .push(.simulator), .push(.grow),
        .push(.tools),
        .push(.tax), .push(.terminalSizing)
      ])
  }

  // MARK: - Both hubs

  func testEveryRowHasAUniqueIDAndOneSymbol() {
    let rows = more().flatMap(\.rows) + PlanHubModel.sections().flatMap(\.rows)
    XCTAssertEqual(Set(rows.map(\.id)).count, rows.count)
    XCTAssertEqual(Set(rows.map(\.systemImage)).count, rows.count)
    // Monochrome outline symbols: no `.fill` variants.
    XCTAssertTrue(rows.allSatisfy { !$0.systemImage.isEmpty && !$0.systemImage.contains(".fill") })
  }

  // MARK: - Taps

  func testFreeUserOnAProRowGetsThePaywallInPlace() {
    let insights = row("insights", in: more())
    XCTAssertEqual(insights?.tap(userIsPro: false), .paywall)
    for id in ["netWorthForecast", "scenarios"] {
      XCTAssertEqual(row(id, in: PlanHubModel.sections())?.tap(userIsPro: false), .paywall, id)
    }
  }

  func testProUserOnAProRowGoesThrough() {
    XCTAssertEqual(row("insights", in: more())?.tap(userIsPro: true), .perform(.push(.insights)))
  }

  func testFreeRowsIgnoreTheEntitlement() {
    let brief = row("marketBrief", in: more())
    XCTAssertEqual(brief?.tap(userIsPro: false), .perform(.selectTab(.today, .marketBrief)))
    XCTAssertEqual(row("reports", in: more())?.tap(userIsPro: false), .perform(.push(.reports)))
  }

  // MARK: - Account row

  func testAccountRowUsesUsernameThenEmail() {
    XCTAssertEqual(MoreHubModel.account(username: "alex", email: "a@b.c"), HubAccount(name: "alex", initial: "A"))
    XCTAssertEqual(MoreHubModel.account(username: "  ", email: "zoe@b.c"), HubAccount(name: "zoe@b.c", initial: "Z"))
    XCTAssertEqual(MoreHubModel.account(username: nil, email: nil), HubAccount(name: nil, initial: "?"))
  }
}
