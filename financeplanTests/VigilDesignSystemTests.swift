import SwiftUI
import XCTest

@testable import financeplan

/// Guards the Vigil design system against silent regressions.
///
/// Classic was retired: it was never the default, and carrying two brands meant
/// every screen had a second rendering path that nothing exercised. What is left
/// here are the invariants whose failures are invisible — a screen renders in
/// the wrong colour, or loses a control, with nothing crashing or logging.
final class VigilDesignSystemTests: XCTestCase {

  private func source(_ relativePath: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
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
      "VigilNavigationAppearance must use the resolved scheme, not a hardcoded fallback."
    )

    // Stronger than the previous `resolvedColorScheme` spelling, which read the
    // live trait once per stored-value change. The appearance proxy now re-applies
    // from \.colorScheme inside AppTintModifier, so it also follows a device
    // light/dark flip while appearance is .system — the case the old imperative
    // onAppear/onChange trio missed.
    XCTAssertTrue(
      src.contains("VigilNavigationAppearance.apply(colorScheme: newScheme)"),
      "Nav-bar chrome must follow the resolved colour scheme."
    )
    XCTAssertFalse(
      src.contains("resolvedColorScheme"),
      "Nav-bar chrome must resolve \\.colorScheme from the environment, not a computed property."
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

  /// Every colour the app actually renders now comes from `Assets.xcassets/Theme`,
  /// not from `AccentColor` — so until this existed, `docs/vigil-identity.md`'s
  /// "web and iOS both derive from this file, do not fork values" was unenforced
  /// on the values that ship.
  ///
  /// Hex is taken verbatim from that file's palette table.
  func testThemeColorsetsMatchTheSharedBrandSpec() throws {
    let expected: [String: (light: String, dark: String)] = [
      "VigilTint": (light: "0x08,0x91,0xB2", dark: "0x00,0xF2,0xFF"),
      "VigilSecondaryTint": (light: "0x0D,0x94,0x88", dark: "0x00,0xFF,0x94"),
      "VigilPageBackground": (light: "0xEE,0xF6,0xF8", dark: "0x05,0x05,0x05"),
      "VigilCardBackground": (light: "0xF7,0xFC,0xFD", dark: "0x0A,0x11,0x16"),
      "VigilElevatedCard": (light: "0xE2,0xEE,0xF2", dark: "0x0F,0x1A,0x21"),
      "VigilForeground": (light: "0x0B,0x1C,0x22", dark: "0xD7,0xF6,0xFA"),
      // The `border` token. This is deliberately NOT the accent tint: it used to
      // be #00F2FF at 18% opacity, which put neon cyan on the outline of every
      // surface in the app.
      "VigilSeparator": (light: "0xC5,0xDB,0xE2", dark: "0x14,0x30,0x3A"),
    ]

    for (name, hex) in expected {
      let json = try source("financeplan/Assets.xcassets/Theme/\(name).colorset/Contents.json")
        .replacingOccurrences(of: " ", with: "")
      for (label, value) in [("light", hex.light), ("dark", hex.dark)] {
        let parts = value.split(separator: ",")
        for (channel, component) in zip(["red", "green", "blue"], parts) {
          XCTAssertTrue(
            json.contains("\"\(channel)\":\"\(component)\""),
            "\(name) \(label) must keep its docs/vigil-identity.md value; expected \(channel) \(component)."
          )
        }
      }
    }
  }

  /// The tint is bright enough that white on it fails contrast badly — 1.39:1 in
  /// dark. `OnTint` is what stops that, so it must stay dark-on-light-tint and
  /// light-on-dark-tint, i.e. inverted relative to every other colorset here.
  func testOnTintInvertsSoLabelsStayReadableOnTheAccent() throws {
    let json = try source("financeplan/Assets.xcassets/Theme/OnTint.colorset/Contents.json")
      .replacingOccurrences(of: " ", with: "")

    guard let darkRange = json.range(of: "\"luminosity\"") else {
      return XCTFail("OnTint must declare a dark appearance variant.")
    }
    let light = String(json[..<darkRange.lowerBound])
    let dark = String(json[darkRange.lowerBound...])

    XCTAssertTrue(light.contains("\"red\":\"0xFB\""), "OnTint light must be near-white for the darker light tint.")
    XCTAssertTrue(dark.contains("\"red\":\"0x05\""), "OnTint dark must be near-black — white on #00F2FF is 1.39:1.")
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
    // would drop .appGlassEffect and leave a flat cardBackground fill with no
    // stroke, shadow or native glass, flattening cards across all 75 sites. Any
    // future change here needs a screenshot review first.
    XCTAssertTrue(src.contains(".appGlassEffect("),
                  "GlassCard must keep the native/fallback glass primitive")

    // Match construction, not any mention: the doc comment in that file
    // deliberately names VigilGlassBackground to explain why it is NOT used.
    XCTAssertFalse(src.contains("VigilGlassBackground("),
                   "swapping in VigilGlassBackground flattens the cards; needs visual review")
  }

  // MARK: - Tab bar chrome

  /// The app used to hide the native tab bar process-wide and draw its own
  /// floating capsule. That cost iPad sidebar adaptation, the accessibility
  /// rotor, scroll-edge behaviour and correct safe-area handling, and the
  /// capsule overflowed at the *default* Dynamic Type size.
  ///
  /// Re-hiding the bar is the one edit that would silently undo all of it, so it
  /// is what this guards.
  func testNativeTabBarIsNotHiddenAgain() throws {
    let home = try source("financeplan/Features/Home/HomeScreen.swift")
    let app = try source("financeplan/NorviqaApp.swift")

    XCTAssertFalse(
      home.contains(".toolbar(.hidden, for: .tabBar)"),
      "hiding the tab bar brings back the custom capsule and everything it cost."
    )
    XCTAssertFalse(
      app.contains("UITabBar.appearance().isHidden"),
      "this appearance proxy is process-wide — it also hides tab bars inside UIKit SDK flows."
    )
    XCTAssertTrue(
      home.contains(".tabViewStyle(.sidebarAdaptable)"),
      "iPad should adapt to a sidebar rather than centre a phone-width bar."
    )
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
    // Previously this named two files and matched only lines *starting* with
    // `.animation(`, so it never saw `withAnimation(` — the form the onboarding
    // import funnel actually uses — and passed while three screens ran ungated
    // springs. It now walks the whole tree and covers both spellings.
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("financeplan/Features/Onboarding")

    let files = FileManager.default
      .enumerator(at: root, includingPropertiesForKeys: nil)?
      .compactMap { $0 as? URL }
      .filter { $0.pathExtension == "swift" } ?? []

    XCTAssertFalse(files.isEmpty, "expected to find onboarding sources under \(root.path)")

    for url in files {
      let src = try String(contentsOf: url, encoding: .utf8)
      // A file that consults reduceMotion anywhere is trusted to gate its own
      // animations; the check is for files that never consider it at all.
      guard !src.contains("reduceMotion") else { continue }

      let name = url.lastPathComponent
      for (i, line) in src.split(separator: "\n").enumerated() {
        let l = line.trimmingCharacters(in: .whitespaces)
        guard l.hasPrefix(".animation(") || l.contains("withAnimation(") else { continue }
        // Static transitions carry no duration and are unaffected by the setting.
        guard l.contains("spring") || l.contains("ease") || l.contains("duration") else { continue }
        XCTFail("\(name):\(i + 1) animates without consulting reduceMotion — gate it or use .appAnimation")
      }
    }
  }

// MARK: - Paywall disclosure

  func testAllThreePaywallEntryPointsDiscloseTerms() throws {
    // Every entry point must independently show price, cancellation and trial
    // terms — a user can reach any one of them without seeing the others.
    for path in [
      "financeplan/Features/UserProfile/PaywallView.swift",
      "financeplan/Features/Auth/PreLoginPaywallScreen.swift",
      "financeplan/Features/Onboarding/Questionnaire/Screens/OnboardingQuestionnairePaywallScreen.swift",
    ] {
      let src = try source(path)
      XCTAssertTrue(src.contains("PaywallTrustStrip"),
                    "\(path) must show the cancellation and trial-charge strip")
      XCTAssertTrue(src.contains("localizedPriceString"),
                    "\(path) must show the real StoreKit price, not a hardcoded one")
    }
  }

  func testPaywallPriceCannotBeTruncatedAtLargeDynamicType() throws {
    let card = try source("financeplan/Components/Paywall/PaywallPlanCard.swift")

    // The card is a horizontal HStack: the title/subtitle column and the price
    // compete for width. At AX5 SwiftUI truncates whichever side loses, and on a
    // paywall that must never be the price. Build-31 was rejected for exactly
    // this class of Dynamic Type failure.
    XCTAssertTrue(card.contains(".layoutPriority(1)"),
                  "the price column must win the width negotiation")
    XCTAssertTrue(card.contains(".fixedSize(horizontal: true, vertical: false)"),
                  "the price must not compress")
    XCTAssertTrue(card.contains(".fixedSize(horizontal: false, vertical: true)"),
                  "the title and subtitle must wrap rather than squeeze the price out")

    let strip = try source("financeplan/Components/Paywall/PaywallTrustStrip.swift")
    XCTAssertTrue(strip.contains(".fixedSize(horizontal: false, vertical: true)"),
                  "three equal columns at AX5 must wrap, not truncate \"Charged after trial\"")
  }
}

