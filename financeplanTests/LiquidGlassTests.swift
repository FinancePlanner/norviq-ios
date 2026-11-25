import XCTest

/// Guards native Liquid Glass against the shim that silently disabled it.
///
/// `FutureCompatibility.swift` used to declare a module-level `Glass`,
/// `GlassEffectContainer` and no-op `glassEffect` overloads under an
/// always-true `#if !canImport(LiquidGlassFramework)`. Module declarations
/// shadow SwiftUI's, so on iOS 26 every "native" glass call resolved to the
/// shim and drew nothing. Nothing crashed or logged; the app just had no glass.
///
/// These are source tests: the failure they catch is invisible at runtime.
/// They scan `.swift` files only (prose in `Documentation/` may name the APIs).
final class LiquidGlassTests: XCTestCase {

  private var repoRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  private func source(_ relativePath: String) throws -> String {
    try String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
  }

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

  private let compatFile = "Extensions/GlassEffect+Compat.swift"

  func testNoFileChecksForTheFakeLiquidGlassFramework() async throws {
    await Task.yield()
    for (name, src) in try appSources() where src.contains("LiquidGlassFramework") {
      XCTFail("\(name) mentions LiquidGlassFramework, the always-true shim guard")
    }
  }

  func testNoFileDeclaresATopLevelGlassTypeThatShadowsSwiftUI() async throws {
    await Task.yield()
    // `\b` stops `struct GlassCard` / `struct GlassEffectModifier` matching.
    let pattern = try NSRegularExpression(
      pattern: #"(struct|enum|class)\s+(Glass|GlassEffectContainer|GlassEffectTransition)\b"#
    )
    for (name, src) in try appSources() {
      let range = NSRange(src.startIndex..., in: src)
      if pattern.firstMatch(in: src, range: range) != nil {
        XCTFail("\(name) declares a type that shadows SwiftUI's Liquid Glass API")
      }
    }
  }

  func testNativeGlassAPIsOnlyInCompat() async throws {
    await Task.yield()
    for (name, src) in try appSources() where name != compatFile {
      for api in [".glassEffect(", "GlassEffectContainer(", ".glassEffectID("] where src.contains(api) {
        XCTFail("\(name) calls \(api) directly; route it through GlassEffect+Compat.swift")
      }
    }
  }

  func testCompatGatesNativeGlassAndHonoursReduceTransparency() async throws {
    await Task.yield()
    let src = try source("financeplan/\(compatFile)")
    XCTAssertTrue(src.contains("#available(iOS 26"), "native glass must sit behind #available(iOS 26, *)")
    XCTAssertTrue(src.contains("struct AppGlassContainer"), "AppGlassContainer wraps GlassEffectContainer")
    XCTAssertTrue(src.contains("func appGlassEffectID("), "appGlassEffectID wraps glassEffectID")
    XCTAssertTrue(src.contains("func appCardSurface("), "appCardSurface is the solid content surface")
    XCTAssertTrue(
      src.contains("accessibilityReduceTransparency"),
      "chrome must fall back to a solid surface when Reduce Transparency is on"
    )
  }

  func testNavigationBarKeepsSystemGlassOnIOS26() async throws {
    await Task.yield()
    let src = try source("financeplan/Components/VigilNavigationAppearance.swift")
    XCTAssertTrue(
      src.contains("#unavailable(iOS 26)") || src.contains("#available(iOS 26"),
      "the opaque UINavigationBarAppearance must not apply on iOS 26"
    )
  }
}
