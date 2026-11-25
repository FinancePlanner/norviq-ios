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

  func testValueNeverWrapsMidNumber() throws {
    let text = try source("financeplan/Components/MetricTile.swift")
    XCTAssertTrue(text.contains(".lineLimit(1)"))
    XCTAssertTrue(text.contains(".minimumScaleFactor("))
  }

  func testHeroRowUsesCompactValues() throws {
    let text = try source("financeplan/Features/Portfolio/PortfolioHeroCard.swift")
    for label in ["\"Positions\"", "\"Avg / position\"", "\"Cash\""] {
      let start = try XCTUnwrap(text.range(of: "MetricTile(\(label)") ?? text.range(of: "MetricTile(\n            \(label)"))
      let tail = String(text[start.lowerBound...])
      let call = String(tail.prefix(upTo: tail.range(of: ")\n")?.upperBound ?? tail.endIndex))
      XCTAssertTrue(call.contains("valueStyle: .compact"), "\(label) must be compact")
    }
    XCTAssertTrue(text.contains(".fixedSize(horizontal: false, vertical: true)"))
  }

  func testCompactStyleUsesNumericTypography() throws {
    let text = try source("financeplan/Components/MetricTile.swift")
    XCTAssertTrue(text.contains("case regular, compact"))
    XCTAssertTrue(text.contains("case .compact: .numeric"))
    XCTAssertTrue(text.contains("case .regular: .metricNumber"))
    XCTAssertTrue(text.contains("maxHeight: .infinity"))
  }

  // MARK: - String catalog

  private func catalogValue(_ key: String, _ language: String) throws -> String? {
    let data = try Data(contentsOf: root.appendingPathComponent("financeplan/Localizable.xcstrings"))
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let strings = try XCTUnwrap(json["strings"] as? [String: Any])
    guard let entry = strings[key] as? [String: Any],
          let locs = entry["localizations"] as? [String: Any],
          let loc = locs[language] as? [String: Any],
          let unit = loc["stringUnit"] as? [String: Any]
    else { return nil }
    return unit["value"] as? String
  }

  func testBudgetTileLabelsHavePortugueseTranslations() throws {
    XCTAssertEqual(try catalogValue("Planned", "pt-PT"), "Planeado")
    XCTAssertEqual(try catalogValue("Left", "pt-PT"), "Restante")
    XCTAssertEqual(try catalogValue("Goal", "pt-PT"), "Objetivo")
    XCTAssertEqual(try catalogValue("Actual", "pt-PT"), "Real")
  }

  func testDeltaAccessibilityKeysCarryThePercent() throws {
    XCTAssertEqual(try catalogValue("up %@", "pt-PT"), "em alta %@")
    XCTAssertEqual(try catalogValue("down %@", "pt-PT"), "em baixa %@")
    XCTAssertNotNil(try catalogValue("unchanged %@", "pt-PT"))
    for old in ["up", "down", "unchanged"] {
      XCTAssertNil(try catalogValue(old, "pt-PT"), "bare key \(old) should be gone")
    }
  }
}
