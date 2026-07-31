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


  // MARK: - Asset catalog

  func testAccentColorUsesVigilAnchorsNotDeprecatedGold() throws {
    let json = try source("financeplan/Assets.xcassets/AccentColor.colorset/Contents.json")

    // Asset catalogs are static and cannot brand-switch, so this is a one-value
    // decision. It is set to the Vigil contrast anchors because Vigil is the
    // default brand: #0891B2 light, #00F2FF dark (docs/vigil-identity.md).
    //
    // It matters despite no Swift code reading it: UIKit and the system use the
    // catalog accent where SwiftUI's .tint cannot reach — LaunchScreen,
    // share sheets, SFSafariViewController — via
    // ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME.
    XCTAssertFalse(
      json.contains("\"red\" : \"0x8F\""),
      "AccentColor light must not be the deprecated gold #8F5E1C."
    )
    XCTAssertFalse(
      json.contains("\"red\" : \"0xE8\""),
      "AccentColor dark must not be the deprecated gold #E8A33D."
    )
    XCTAssertTrue(json.contains("\"blue\" : \"0xB2\""), "expected Vigil light anchor #0891B2")
    XCTAssertTrue(json.contains("\"green\" : \"0xF2\""), "expected Vigil dark anchor #00F2FF")
  }

  func testLaunchScreenBackgroundAdaptsToAppearance() throws {
    let plist = try source("Info.plist")

    // The launch screen is the UILaunchScreen dictionary, NOT
    // LaunchScreen.storyboard — that file is not referenced anywhere in
    // project.pbxproj, so it never enters the build. An empty dict rendered
    // plain systemBackground; naming a colorset matches the app's own page
    // background so a dark launch no longer flashes a lighter panel.
    XCTAssertTrue(
      plist.contains("<key>UIColorName</key>"),
      "UILaunchScreen must name a background colorset."
    )
    XCTAssertTrue(
      plist.contains("<string>LaunchBackground</string>"),
      "the launch background should be the LaunchBackground colorset."
    )

    let colorset = try source("financeplan/Assets.xcassets/LaunchBackground.colorset/Contents.json")
    XCTAssertTrue(colorset.contains("\"value\" : \"dark\""),
                  "LaunchBackground needs a dark variant or the launch screen cannot adapt.")
  }

  // MARK: - Dead navigation

  func testNoPlaceholderSettingsDestinationsRemain() throws {
    let src = try source("financeplan/Features/UserProfile/UserProfileView.swift")

    // .dataHandling and .sensitiveActions had no push sites anywhere, so they
    // were unreachable enum cases whose bodies were bare Text placeholders.
    XCTAssertFalse(src.contains("Text(\"Data handling\")"),
                   "unreachable placeholder destination should be removed, not shipped")
    XCTAssertFalse(src.contains("Text(\"Sensitive actions\")"),
                   "unreachable placeholder destination should be removed, not shipped")
    XCTAssertFalse(src.contains("case dataHandling"))
    XCTAssertFalse(src.contains("case sensitiveActions"))
  }

  func testBankSyncStaysReachableFromSettingsInTwoTaps() throws {
    let profile = try source("financeplan/Features/UserProfile/UserProfileView.swift")
    let integrations = try source("financeplan/Features/Integrations/IntegrationsView.swift")

    // Settings > Connected Accounts > Bank Sync. PR #60 had to restore this
    // entry once; keep the shallow path intact.
    XCTAssertTrue(profile.contains("UserProfileDestination.integrations"),
                  "Settings must keep a direct row to the functional integrations screen")
    XCTAssertTrue(integrations.contains("BankingView()"),
                  "bank sync must stay reachable from IntegrationsView")
  }

  // MARK: - Card surfaces

  func testGlassCardKeepsAdaptiveDefaultPadding() throws {
    let src = try source("financeplan/Components/GlassCard.swift")

    // `.padding()` and `.padding(16)` are NOT equivalent — the no-argument form
    // is adaptive. All 75 existing call sites render the adaptive one, so the
    // nil branch must keep calling it with no argument.
    XCTAssertTrue(src.contains("content.padding()"),
                  "the default padding branch must stay adaptive, not a fixed value")
    XCTAssertTrue(src.contains("padding: CGFloat? = nil"),
                  "padding must be opt-in so existing call sites are unaffected")
  }

  func testGlassCardStillAppliesAppGlassEffect() throws {
    let src = try source("financeplan/Components/GlassCard.swift")

    // Guards the consolidation trap: pointing GlassCard at VigilGlassBackground
    // would drop .appGlassEffect, and VigilGlassBackground's Classic branch is a
    // flat cardBackground fill with no stroke, shadow or native glass. That
    // would flatten Classic cards across all 75 sites. Any future change here
    // needs a screenshot review first.
    XCTAssertTrue(src.contains(".appGlassEffect("),
                  "GlassCard must keep the native/fallback glass primitive")

    // Match construction, not any mention: the doc comment in that file
    // deliberately names VigilGlassBackground to explain why it is NOT used.
    XCTAssertFalse(src.contains("VigilGlassBackground("),
                   "swapping in VigilGlassBackground flattens Classic cards; needs visual review")
  }

  // MARK: - Tab bar chrome

  func testTabBarStrokeFollowsTheBrandInsteadOfHardcodedWhite() throws {
    let src = try source("financeplan/Components/RevolutTabBar.swift")

    // A white hairline over a light page is barely visible, and it cannot follow
    // the brand at all — the same defect class as border-white/10 on the web.
    XCTAssertFalse(
      src.contains("Color.white.opacity(colorScheme == .dark ? 0.12 : 0.22)"),
      "the capsule stroke must not be a hardcoded white"
    )
    XCTAssertTrue(src.contains("capsuleStroke"),
                  "the capsule stroke should resolve from AppTheme per brand")
  }

  func testTabBarDoesNotUseAppGlassEffect() throws {
    let src = try source("financeplan/Components/RevolutTabBar.swift")

    // Deliberate exception to the glass consolidation: on iOS 26 the native
    // glassEffect expands to the full ZStack proposal and covers the screen.
    // The raw .ultraThinMaterial here is load-bearing, and the file says so.
    //
    // Comments are stripped first — the file explains WHY it avoids
    // appGlassEffect, so a naive substring check matches its own documentation.
    // (The CSS brand-layout checker needed the same fix for the same reason.)
    let code = src
      .split(separator: "\n")
      .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
      .joined(separator: "\n")

    XCTAssertFalse(code.contains(".appGlassEffect("),
                   "appGlassEffect on the tab capsule covers the screen on iOS 26")
    XCTAssertTrue(code.contains(".fill(.ultraThinMaterial)"))
  }

  // MARK: - Credential autofill

  func testEveryCodeEntryFieldOffersOneTimeCodeAutofill() throws {
    // Without .oneTimeCode iOS never surfaces the code in the QuickType bar, so
    // the user leaves the app, memorises six digits and types them back. It
    // fails nothing and logs nothing; it just quietly costs a sign-in.
    for path in [
      "financeplan/Features/Auth/VaultMFAVerificationView.swift",
      "financeplan/ContentView.swift",
      "financeplan/Features/UserProfile/ProfileViews/SecurityCodeView.swift",
    ] {
      let src = try source(path)
      XCTAssertTrue(
        src.contains(".textContentType(.oneTimeCode)"),
        "\(path) takes a verification code and must opt into one-time-code autofill"
      )
    }
  }

  func testCredentialFieldsDeclareTheirContentType() throws {
    let signIn = try source("financeplan/Features/Auth/SignInView.swift")
    let signUp = try source("financeplan/Features/Auth/SignUpView.swift")

    // The web forms shipped with no autocomplete at all (#65). iOS already had
    // these; this pins them so the same regression cannot happen here.
    XCTAssertTrue(signIn.contains("textContentType: .emailAddress"))
    XCTAssertTrue(signIn.contains("textContentType: .password"))
    XCTAssertTrue(signUp.contains("textContentType: .username"))
    XCTAssertTrue(signUp.contains("textContentType: .newPassword"))
  }

// MARK: - Reduce Motion

  func testOnboardingAnimationsRespectReduceMotion() throws {
    // .appAnimation swaps in AppMotion.reduced when accessibilityReduceMotion is
    // on; a raw .animation(...) does not, so the spring plays anyway. Onboarding
    // is the conversion-critical flow and the worst place to ignore the setting.
    //
    // A raw call is acceptable ONLY when the line itself branches on
    // reduceMotion, which the questionnaire paywall does explicitly.
    let files = [
      "financeplan/Features/Onboarding/InitialStockImportScreen.swift",
      "financeplan/Features/Onboarding/Questionnaire/Screens/OnboardingGoalScreen.swift",
    ]
    for path in files {
      let src = try source(path)
      for (i, line) in src.split(separator: "\n").enumerated() {
        let l = line.trimmingCharacters(in: .whitespaces)
        guard l.hasPrefix(".animation(") else { continue }
        XCTFail("\(path):\(i + 1) uses a raw .animation(...) — use .appAnimation so Reduce Motion is honored")
      }
    }
  }
}

