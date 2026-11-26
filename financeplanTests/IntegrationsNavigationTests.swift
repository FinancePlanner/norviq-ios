import XCTest

@testable import financeplan

final class IntegrationsNavigationTests: XCTestCase {
  func testIntegrationsViewKeepsBankSyncNavigationVisible() throws {
    let sourceURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("financeplan/Features/Integrations/IntegrationsView.swift")
    let source = try String(contentsOf: sourceURL, encoding: .utf8)

    XCTAssertTrue(
      source.contains("BankingView()"),
      "Bank Sync must remain reachable from IntegrationsView."
    )
    XCTAssertTrue(
      source.contains(".accessibilityIdentifier(\"integrations.bankSync\")"),
      "Bank Sync navigation needs a stable identifier for UI regression coverage."
    )
  }
}
