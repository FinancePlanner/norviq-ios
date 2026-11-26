import XCTest

/// Guards the single Q entry point.
///
/// Q used to have two ways in: a floating button that guessed the tab bar's
/// height, and a toolbar sparkle on eight screens. Both are gone; these source
/// tests stop either from coming back. They scan `.swift` files only.
final class QEntryPointTests: XCTestCase {

  private var repoRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  private let entryPointFile = "Features/QuickAssistant/QEntryPoint.swift"

  /// Every app `.swift` file under `financeplan/`, as (path relative to it, contents).
  private func appSources() throws -> [(name: String, src: String)] {
    let root = repoRoot.appendingPathComponent("financeplan")
    let files = FileManager.default
      .enumerator(at: root, includingPropertiesForKeys: nil)?
      .compactMap { $0 as? URL }
      .filter { $0.pathExtension == "swift" } ?? []
    XCTAssertFalse(files.isEmpty, "expected to find app sources under \(root.path)")
    return try files.map { url in
      let name = String(url.path.dropFirst(root.path.count + 1))
      return (name, try String(contentsOf: url, encoding: .utf8))
    }
  }

  func testNoFileUsesTheRetiredEntryPoints() async throws {
    await Task.yield()
    let retired = ["tabBarHeight", ".aiViewSummary(", "hidesQuickAssistantButton"]
    for (name, src) in try appSources() {
      for needle in retired where src.contains(needle) {
        XCTFail("\(name) still contains \(needle)")
      }
    }
  }

  func testExactlyTheBottomActionScreensHideQ() async throws {
    await Task.yield()
    let hiders = try appSources()
      .filter { $0.src.contains(".hidesQAccessory()") }
      .map { ($0.name as NSString).lastPathComponent }
      .sorted()
    XCTAssertEqual(hiders, ["BoardPostDetailScreen.swift", "GroupChatView.swift", "RebalancingScreen.swift"])
  }

  /// The accessory API is iOS 26 only and the app deploys to iOS 18, so every
  /// use must sit behind an iOS 26 availability check, and only in one file.
  func testTheAccessoryIsOnlyUsedBehindAnIOS26Check() async throws {
    await Task.yield()
    let sources = try appSources()
    let users = sources.filter { $0.src.contains("tabViewBottomAccessory") }.map(\.name)
    XCTAssertEqual(users, [entryPointFile], "tabViewBottomAccessory belongs in QEntryPoint.swift only")

    guard let src = sources.first(where: { $0.name == entryPointFile })?.src else {
      return XCTFail("\(entryPointFile) is missing")
    }
    var searchStart = src.startIndex
    var uses = 0
    while let use = src.range(of: "tabViewBottomAccessory", range: searchStart..<src.endIndex) {
      uses += 1
      let before = src[src.startIndex..<use.lowerBound]
      let check = before.range(of: "#available(", options: .backwards)
      XCTAssertNotNil(check, "tabViewBottomAccessory use \(uses) has no #available check before it")
      if let check {
        XCTAssertTrue(
          src[check.lowerBound...].hasPrefix("#available(iOS 26"),
          "tabViewBottomAccessory use \(uses) is not behind #available(iOS 26…)"
        )
      }
      searchStart = use.upperBound
    }
    XCTAssertGreaterThan(uses, 0, "QEntryPoint.swift does not use tabViewBottomAccessory")
  }
}
