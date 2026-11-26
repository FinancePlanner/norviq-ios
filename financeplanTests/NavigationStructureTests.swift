import SwiftUI
import XCTest

@testable import financeplan

/// One `NavigationStack` per tab root: a screen a hub pushes joins the hub's
/// stack instead of wrapping its own, which drew a second navigation bar.
/// The source checks scan `.swift` files; sheet stacks are allowed.
final class NavigationStructureTests: XCTestCase {

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

  /// The screens a hub pushes that used to own a stack, and how many sheet
  /// stacks each keeps.
  private let pushedRoots: [(path: String, type: String, sheetStacks: Int)] = [
    ("Features/Tax/TaxDashboardScreen.swift", "TaxDashboardScreen", 3),
    ("Features/Insights/InsightsScreen.swift", "InsightsScreen", 0),
    ("Features/Expenses/ExpensesComparisonScreen.swift", "ExpensesComparisonScreen", 2),
    ("Features/Crypto/CryptoHomeView.swift", "CryptoHomeView", 0),
    ("Features/Social/SocialRoot.swift", "SocialRoot", 0),
    ("Features/Groups/GroupsRoot.swift", "GroupsRoot", 0),
    ("Features/UserProfile/UserProfileView.swift", "UserProfileView", 0),
    ("Features/GoalPlanning/GoalPlanningScreen.swift", "GoalPlanningScreen", 1),
  ]

  func testPushedRootsDoNotWrapTheirOwnStack() async throws {
    await Task.yield()
    for root in pushedRoots {
      let src = try code(root.path)
      guard let type = src.range(of: "struct \(root.type)"),
        let body = src.range(of: "var body: some View {", range: type.upperBound..<src.endIndex)
      else {
        XCTFail("\(root.path): no body for \(root.type)")
        continue
      }
      let firstStatement = src[body.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
      XCTAssertFalse(
        firstStatement.hasPrefix("NavigationStack"), "\(root.type)'s body still begins with a NavigationStack")
      XCTAssertEqual(
        src.components(separatedBy: "NavigationStack").count - 1, root.sheetStacks,
        "\(root.path) may keep only its sheet stacks")
    }
  }

  func testSettingsIsAPushWithoutItsOwnDoneOrQ() async throws {
    await Task.yield()
    let src = try code("Features/UserProfile/UserProfileView.swift")
    XCTAssertFalse(src.contains("\"Done\""), "the presenter owns Done; a push has the back button")
    XCTAssertFalse(src.contains("accessibilityLabel(\"Q\")"), "Q comes from the tab accessory")
    XCTAssertFalse(src.contains("isAssistantPresented"))
    XCTAssertTrue(src.contains(".navigationDestination(for: UserProfileDestination.self)"))
  }

  func testGoalsLeavesItsCloseButtonToThePresenter() async throws {
    await Task.yield()
    XCTAssertFalse(try code("Features/GoalPlanning/GoalPlanningScreen.swift").contains("xmark"))
    XCTAssertTrue(
      try code("Features/Home/DashboardRoot.swift").contains("Close financial goals"),
      "the full-screen cover still needs a way out")
  }

  func testCryptoNoLongerOpensSettings() async throws {
    await Task.yield()
    let src = try code("Features/Crypto/CryptoHomeView.swift")
    XCTAssertFalse(src.contains("isSettingsPresented"))
    XCTAssertFalse(src.contains("\"gearshape\""))
  }

  func testSocialAndGroupsPushOntoTheEnclosingPath() async throws {
    await Task.yield()
    for path in ["Features/Social/SocialRoot.swift", "Features/Groups/GroupsRoot.swift"] {
      let src = try code(path)
      XCTAssertTrue(src.contains("@Binding var path: NavigationPath"), "\(path) must push onto the hub's path")
      XCTAssertFalse(src.contains("@State private var path"), "\(path) must not keep a path of its own")
    }
  }

  // MARK: - Groups on a shared path

  /// A path holding `items`, bottom first, to compare a whole path with:
  /// `NavigationPath` is equatable, so this checks the top element too.
  private func pathOf(_ items: any Hashable...) -> NavigationPath {
    var path = NavigationPath()
    for item in items { path.append(item) }
    return path
  }

  func testAGroupsLinkPopsToGroupsThenPushes() {
    let linked = UUID()
    var path = pathOf(AppDestination.groups, GroupsRoute.discover, GroupsRoute.group(UUID(), channelID: nil))

    GroupsRoute.show(.group(linked, channelID: nil), on: &path, above: 1)

    XCTAssertEqual(path, pathOf(AppDestination.groups, GroupsRoute.group(linked, channelID: nil)), "More > Groups > the linked group")
  }

  func testAnInvitationsLinkReturnsToGroups() {
    var path = pathOf(AppDestination.groups, GroupsRoute.discover)

    GroupsRoute.show(nil, on: &path, above: 1)

    XCTAssertEqual(path, pathOf(AppDestination.groups), "back on Groups, More's root stays below it")
  }

  func testGroupsAsATabRootStartsAtDepthZero() {
    var path = NavigationPath()

    GroupsRoute.show(.discover, on: &path, above: 0)

    XCTAssertEqual(path, pathOf(GroupsRoute.discover))
  }

  func testGroupsNeverPopsBelowItself() {
    var path = pathOf(AppDestination.groups)

    GroupsRoute.show(.discover, on: &path, above: 1)

    XCTAssertEqual(path, pathOf(AppDestination.groups, GroupsRoute.discover))
  }

  // MARK: - Groups deep links

  func testAChannelLinkReplacesTheOpenGroup() {
    let group = UUID(), channel = UUID()
    var path = pathOf(AppDestination.groups, GroupsRoute.group(UUID(), channelID: nil))

    let followUp = GroupsRoute.follow(.channel(groupID: group, channelID: channel), on: &path, above: 1)

    XCTAssertEqual(followUp, .nothing)
    XCTAssertEqual(path, pathOf(AppDestination.groups, GroupsRoute.group(group, channelID: channel)))
  }

  func testAGroupLinkReplacesTheOpenGroup() {
    let group = UUID()
    var path = pathOf(AppDestination.groups, GroupsRoute.discover, GroupsRoute.group(UUID(), channelID: nil))

    let followUp = GroupsRoute.follow(.group(group), on: &path, above: 1)

    XCTAssertEqual(followUp, .nothing)
    XCTAssertEqual(path, pathOf(AppDestination.groups, GroupsRoute.group(group, channelID: nil)))
  }

  func testAnInvitationsLinkReturnsToGroupsAndReloads() {
    var path = pathOf(AppDestination.groups, GroupsRoute.discover)

    let followUp = GroupsRoute.follow(.invitations, on: &path, above: 1)

    XCTAssertEqual(followUp, .reloadInvitations)
    XCTAssertEqual(path, pathOf(AppDestination.groups))
  }

  /// The join sheet hangs off Groups' own screen. With a group open on top,
  /// that screen is off screen until the pop lands, and a sheet asked of it
  /// mid-pop can be dropped, so the sheet waits for Groups to appear again.
  func testAnInviteOverAnOpenGroupWaitsForGroupsToAppear() {
    var path = pathOf(AppDestination.groups, GroupsRoute.group(UUID(), channelID: nil))

    let followUp = GroupsRoute.follow(.invite(code: "abc"), on: &path, above: 1)

    XCTAssertEqual(followUp, .join(code: "abc", afterReturn: true))
    XCTAssertEqual(path, pathOf(AppDestination.groups))
  }

  func testAnInviteOnGroupsItselfOpensTheSheetAtOnce() {
    var path = pathOf(AppDestination.groups)

    let followUp = GroupsRoute.follow(.invite(code: "abc"), on: &path, above: 1)

    XCTAssertEqual(followUp, .join(code: "abc", afterReturn: false))
    XCTAssertEqual(path, pathOf(AppDestination.groups))
  }

  func testGroupsRootPresentsADeferredJoinOnlyWhenItAppears() async throws {
    await Task.yield()
    let src = try code("Features/Groups/GroupsRoot.swift")
    XCTAssertTrue(src.contains("GroupsRoute.follow("), "GroupsRoot routes links through GroupsRoute.follow")
    guard let start = src.range(of: ".onAppear {"), let end = src.range(of: ".task {", range: start.upperBound..<src.endIndex) else {
      return XCTFail("GroupsRoot keeps an onAppear ahead of its task")
    }
    let onAppear = src[start.upperBound..<end.lowerBound]
    XCTAssertTrue(onAppear.contains("joinCode = request"), "a held invite is shown when Groups appears again")
    XCTAssertTrue(src.contains("joinOnReturn = GroupJoinRequest(code: code)"), "a covered Groups holds the invite until it appears")
  }
}
