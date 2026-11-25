import XCTest
@testable import financeplan

/// `MetricTile` replaces the three hand-rolled metric tiles (DS 2.0 P2b).
final class MetricTileTests: XCTestCase {
  private var root: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  private func source(_ relativePath: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
  }

  private func swiftFiles() throws -> [URL] {
    let base = root.appendingPathComponent("financeplan")
    let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)
    var files: [URL] = []
    while let url = walker?.nextObject() as? URL {
      guard url.pathExtension == "swift" else { continue }
      files.append(url)
    }
    return files
  }

  func testNoDuplicateTileTypesRemain() throws {
    let files = try swiftFiles()
    XCTAssertFalse(files.isEmpty)
    for url in files {
      let text = try String(contentsOf: url, encoding: .utf8)
      XCTAssertFalse(text.contains("struct MetricItem: View"), "\(url.lastPathComponent)")
      XCTAssertFalse(text.contains("struct SummaryMetric: View"), "\(url.lastPathComponent)")
      XCTAssertFalse(text.contains("struct PortfolioMetricPill"), "\(url.lastPathComponent)")
    }
  }

  func testCommentedOutCopyIsGone() throws {
    let text = try source("financeplan/Features/Expenses/BudgetCategoryDetailsScreen.swift")
    XCTAssertFalse(text.contains("//private struct MetricItem"))
  }

  func testMetricTileUsesControlRadiusToken() throws {
    let text = try source("financeplan/Components/MetricTile.swift")
    XCTAssertTrue(text.contains("AppTheme.Radius.control"))
    XCTAssertNil(text.range(of: #"cornerRadius:\s*[0-9]"#, options: .regularExpression))
  }
}
