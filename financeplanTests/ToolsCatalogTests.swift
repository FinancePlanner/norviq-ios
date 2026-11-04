import Foundation
import XCTest
@testable import financeplan

@MainActor
final class ToolsCatalogTests: XCTestCase {
  func testListsTheFiveToolsInOrder() {
    XCTAssertEqual(
      ToolsCatalog.entries.map(\.route),
      [.grow, .retire, .terminalPositions, .simulator, .rebalancingRules]
    )
  }

  func testOnlyRebalancingRequiresPro() {
    XCTAssertEqual(ToolsCatalog.entries.filter(\.requiresPro).map(\.route), [.rebalancingRules])
  }

  func testGrowAnswersTheOriginalRequest() {
    XCTAssertEqual(ToolsCatalog.entries.first?.question, "How much will I have in X years?")
  }

  func testEveryNewStringHasPortuguese() throws {
    let catalogURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("financeplan/Localizable.xcstrings")
    let catalog = try XCTUnwrap(
      JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
    )
    let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
    let keys = ToolsCatalog.entries.map(\.question) + [
      "Tools", "All tools", "Calculators and planners for your money, in one place."
    ]
    for key in keys {
      let entry = strings[key] as? [String: Any]
      let localizations = entry?["localizations"] as? [String: Any]
      let portuguese = (localizations?["pt-PT"] as? [String: Any])?["stringUnit"] as? [String: Any]
      XCTAssertNotNil(portuguese?["value"] as? String, "Missing pt-PT for \(key)")
    }
  }
}
