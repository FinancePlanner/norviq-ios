import SwiftUI
import XCTest

@testable import financeplan

/// Guards brand parity between Vigil and Classic.
///
/// `docs/vigil-identity.md` requires Classic to stay fully functional and
/// selectable, but the failures here are all silent: a screen simply renders
/// less, or renders in the wrong colour, with nothing crashing or logging.
final class BrandThemeParityTests: XCTestCase {

  private func source(_ relativePath: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
  }

  // MARK: - VigilPageHeader

  func testVigilPageHeaderRendersSomethingUnderClassic() throws {
    let src = try source("financeplan/Components/VigilPageHeader.swift")

    // The body used to be a bare `if BrandTheme.current == .vigil { … }` with no
    // else, so 49 of 59 call sites silently dropped their subtitle under Classic.
    XCTAssertTrue(
      src.contains("} else if subtitle != nil || hasTrailing {"),
      "VigilPageHeader must render a Classic branch, not fall through to EmptyView."
    )
  }

  func testVigilPageHeaderClassicBranchDoesNotDuplicateTheTitle() throws {
    let src = try source("financeplan/Components/VigilPageHeader.swift")

    guard let elseRange = src.range(of: "} else if subtitle != nil || hasTrailing {") else {
      return XCTFail("Classic branch missing; see testVigilPageHeaderRendersSomethingUnderClassic.")
    }
    let classicBranch = String(src[elseRange.lowerBound...])

    // Under Classic `vigilNavigationTitle` resolves to the real title, so every
    // unguarded call site already shows it in the navigation bar. Drawing
    // Text(title) here would double the title on ~49 screens.
    XCTAssertFalse(
      classicBranch.contains("Text(title)"),
      "Classic already shows the title in the nav bar; the in-content header must not repeat it."
    )

    // "WATCH I — WEALTH" is Vigil vocabulary and must not leak into Classic.
    XCTAssertFalse(
      classicBranch.contains("watch.eyebrow"),
      "The WATCH eyebrow is Vigil-only vocabulary and must not render under Classic."
    )

    XCTAssertTrue(
      classicBranch.contains("Text(subtitle)"),
      "Classic must render the subtitle — that is the content it was losing."
    )
  }

  // BrandTheme.current and VigilNavigationTitle.display are @MainActor-isolated
  // under Swift 6 strict concurrency, so this case must hop to the main actor.
  @MainActor
  func testVigilNavigationTitleStillBlanksOnlyUnderVigil() throws {
    // The Classic branch above depends on this being true. If the nav title ever
    // blanks under Classic too, Classic screens lose their title entirely and
    // VigilPageHeader must start rendering it.
    XCTAssertEqual(
      VigilNavigationTitle.display("Portfolio"),
      BrandTheme.current == .vigil ? "" : "Portfolio"
    )
  }

  // MARK: - Root tint

  func testRootTintResolvesFromEnvironmentNotStoredAppearance() throws {
    let src = try source("financeplan/NorviqaApp.swift")

    // `appAppearance.colorScheme` is nil for .system (the default), so
    // `?? .light` applied the light tint on dark devices for most users.
    XCTAssertFalse(
      src.contains("AppTheme.Colors.tint(for: appAppearance.colorScheme ?? .light)"),
      "Root tint must not derive the scheme from the stored appearance setting."
    )
    XCTAssertTrue(
      src.contains("AppTintModifier"),
      "Root tint must resolve \\.colorScheme from the environment."
    )
  }

  func testAppearanceDependentUIKitChromeUsesResolvedScheme() throws {
    let src = try source("financeplan/NorviqaApp.swift")

    // Same root cause, opposite fallback: these defaulted to .dark while the
    // tint defaulted to .light, so the two disagreed on a light system device.
    XCTAssertFalse(
      src.contains("colorScheme: appAppearance.colorScheme ?? .dark"),
      "VigilNavigationAppearance must use resolvedColorScheme, not a hardcoded fallback."
    )
    XCTAssertTrue(
      src.contains("VigilNavigationAppearance.apply(colorScheme: resolvedColorScheme)"),
      "Nav-bar chrome must follow the resolved colour scheme."
    )
  }
}
