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

  func testAGroupsLinkPopsToGroupsThenPushes() {
    var path = NavigationPath()
    path.append(AppDestination.groups)
    path.append(GroupsRoute.discover)
    path.append(GroupsRoute.group(UUID(), channelID: nil))

    GroupsRoute.show(.group(UUID(), channelID: nil), on: &path, above: 1)

    XCTAssertEqual(path.count, 2, "More > Groups > the linked group")
  }

  func testAnInvitationsLinkReturnsToGroups() {
    var path = NavigationPath()
    path.append(AppDestination.groups)
    path.append(GroupsRoute.discover)

    GroupsRoute.show(nil, on: &path, above: 1)

    XCTAssertEqual(path.count, 1, "back on Groups, More's root stays below it")
  }

  func testGroupsAsATabRootStartsAtDepthZero() {
    var path = NavigationPath()

    GroupsRoute.show(.discover, on: &path, above: 0)

    XCTAssertEqual(path.count, 1)
  }

  func testGroupsNeverPopsBelowItself() {
    var path = NavigationPath()
    path.append(AppDestination.groups)

    GroupsRoute.show(.discover, on: &path, above: 1)

    XCTAssertEqual(path.count, 2)
  }
}
