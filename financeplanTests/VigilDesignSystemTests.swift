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

  func testRootTintResolvesFromEnvironmentNotStoredAppearance() async throws {
    await Task.yield()
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

  func testAppearanceDependentUIKitChromeUsesResolvedScheme() async throws {
    await Task.yield()
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

  func testAccentColorUsesPrecisionGoldNotVigilCyan() async throws {
    await Task.yield()
    let json = try source("financeplan/Assets.xcassets/AccentColor.colorset/Contents.json")
      .replacingOccurrences(of: " ", with: "")

    // Asset catalogs cannot brand-switch, so this is a one-value decision: the
    // Precision gold, deep #80612A light and Champagne #D8B477 dark
    // (docs/precision-identity.md).
    //
    // It matters despite no Swift code reading it: UIKit and the system use the
    // catalog accent where SwiftUI's .tint cannot reach — LaunchScreen,
    // share sheets, SFSafariViewController — via
    // ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME.
    XCTAssertFalse(json.contains("\"green\":\"0xF2\""), "AccentColor dark must not be the retired Vigil cyan #00F2FF.")
    XCTAssertTrue(json.contains("\"red\":\"0x80\""), "expected Precision light gold #80612A")
    XCTAssertTrue(json.contains("\"red\":\"0xD8\""), "expected Precision dark gold #D8B477")
  }

  /// Every colour the app actually renders comes from `Assets.xcassets/Theme`,
  /// not from `AccentColor`. Those sets are generated from `Design/tokens.json`
  /// (a byte copy of the web master, `norviq-web-v2/design/tokens.json`) by
  /// `scripts/tokens/generate_colorsets.py`, so the two platforms cannot fork a
  /// value without this failing.
  ///
  /// Exact, light and dark, alpha included, for every set in the folder: a set
  /// with no token fails too, so nothing ships outside the generated range.
  func testEveryThemeColorsetMatchesTokensExactly() async throws {
    await Task.yield()
    let tokens = try iosColorTokens()
    let themeDir = repoURL("financeplan/Assets.xcassets/Theme")
    let sets = try FileManager.default.contentsOfDirectory(atPath: themeDir.path)
      .filter { $0.hasSuffix(".colorset") }
      .map { String($0.dropLast(".colorset".count)) }

    // 16 Vigil* sets, OnTint and TertiaryFill. A count guard keeps the loop
    // below from passing vacuously on an empty folder or an unread file.
    XCTAssertEqual(sets.count, 18, "expected 18 Theme colour sets, found \(sets.sorted())")
    XCTAssertEqual(Set(sets), Set(tokens.keys), "Theme colour sets and tokens.json iOS names must be the same set")

    for name in sets.sorted() {
      guard let token = tokens[name] else { continue }
      let data = try Data(contentsOf: themeDir.appendingPathComponent("\(name).colorset/Contents.json"))
      let entries = try XCTUnwrap(
        (JSONSerialization.jsonObject(with: data) as? [String: Any])?["colors"] as? [[String: Any]],
        "\(name): no colors array"
      )
      let universal = entries.filter { $0["appearances"] == nil }
      let dark = entries.filter { entry in
        (entry["appearances"] as? [[String: String]])?
          .contains { $0["appearance"] == "luminosity" && $0["value"] == "dark" } ?? false
      }
      XCTAssertEqual(universal.count, 1, "\(name): expected one universal (light) colour")
      XCTAssertEqual(dark.count, 1, "\(name): expected one dark-appearance colour")

      for (label, entry, hex) in [("light", universal.first, token.light), ("dark", dark.first, token.dark)] {
        let actual = try XCTUnwrap(
          (entry?["color"] as? [String: Any])?["components"] as? [String: String],
          "\(name) \(label): no components"
        )
        XCTAssertEqual(
          actual, try components(hex),
          "\(name) \(label) must equal \(token.path) in tokens.json (\(hex)). Edit the web master, copy it, run `make tokens`."
        )
      }
    }
  }

  /// Spacing and radius are not generated, so they are checked against the
  /// same file. iOS names its steps xs…xxl; tokens.json names them by multiple
  /// of 4. `radius.sm` (8) and `radius.pill` have no iOS counterpart.
  @MainActor
  func testSpacingAndRadiusMatchTokens() throws {
    let root = try tokensJSON()
    func px(_ path: String) throws -> CGFloat {
      var node: Any? = root
      for key in path.split(separator: ".") {
        node = (node as? [String: Any])?[String(key)]
      }
      let value = try XCTUnwrap((node as? [String: Any])?["$value"] as? String, "tokens.json has no \(path)")
      XCTAssertTrue(value.hasSuffix("px"), "\(path) must be px, got \(value)")
      return CGFloat(try XCTUnwrap(Double(value.dropLast(2)), "\(path): \(value)"))
    }

    XCTAssertEqual(AppTheme.Spacing.xs, try px("space.1"))
    XCTAssertEqual(AppTheme.Spacing.sm, try px("space.2"))
    XCTAssertEqual(AppTheme.Spacing.md, try px("space.3"))
    XCTAssertEqual(AppTheme.Spacing.lg, try px("space.4"))
    XCTAssertEqual(AppTheme.Spacing.xl, try px("space.6"))
    XCTAssertEqual(AppTheme.Spacing.xxl, try px("space.8"))
    XCTAssertEqual(AppTheme.Radius.control, try px("radius.control"))
    XCTAssertEqual(AppTheme.Radius.card, try px("radius.card"))
    XCTAssertEqual(AppTheme.Radius.hero, try px("radius.hero"))
  }

  // MARK: tokens.json helpers

  private func repoURL(_ relativePath: String) -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent(relativePath)
  }

  private func tokensJSON() throws -> [String: Any] {
    let data = try Data(contentsOf: repoURL("financeplan/Design/tokens.json"))
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  private struct ColorToken {
    let path: String
    let light: String
    let dark: String
  }

  /// `[iOS colour-set name: token]` for every colour token that names one.
  private func iosColorTokens() throws -> [String: ColorToken] {
    var found: [String: ColorToken] = [:]
    func walk(_ node: [String: Any], _ path: [String]) {
      if node["$type"] as? String == "color" {
        let norviq = (node["$extensions"] as? [String: Any])?["norviq"] as? [String: Any]
        if let name = norviq?["ios"] as? String {
          XCTAssertNil(found[name], "\(name) is named by two tokens")
          found[name] = ColorToken(
            path: path.joined(separator: "."),
            light: node["$value"] as? String ?? "",
            dark: norviq?["dark"] as? String ?? ""
          )
        }
        return
      }
      for (key, child) in node where !key.hasPrefix("$") {
        if let child = child as? [String: Any] { walk(child, path + [key]) }
      }
    }
    walk(try XCTUnwrap(tokensJSON()["color"] as? [String: Any]), ["color"])
    return found
  }

  /// The colour-set components a token hex must produce. Alpha is the last
  /// byte, written as round(byte / 255, 2) to three places: 0x1A is "0.100".
  private func components(_ hex: String) throws -> [String: String] {
    XCTAssertTrue(hex.hasPrefix("#") && (hex.count == 7 || hex.count == 9), "bad token hex \(hex)")
    let digits = Array(hex.dropFirst())
    let bytes = try stride(from: 0, to: digits.count, by: 2).map {
      try XCTUnwrap(UInt8(String(digits[$0..<$0 + 2]), radix: 16), "bad token hex \(hex)")
    }
    let alpha = bytes.count == 4 ? (Double(bytes[3]) / 255 * 100).rounded() / 100 : 1
    return [
      "red": String(format: "0x%02X", bytes[0]),
      "green": String(format: "0x%02X", bytes[1]),
      "blue": String(format: "0x%02X", bytes[2]),
      "alpha": String(format: "%.3f", alpha)
    ]
  }

  /// White on the dark-mode Champagne gold is 1.96:1. `OnTint` is what stops
  /// that: white on the deep light-mode gold (5.7:1), Obsidian on the bright
  /// dark-mode gold (9.7:1).
  func testOnTintInvertsSoLabelsStayReadableOnTheAccent() async throws {
    await Task.yield()
    let json = try source("financeplan/Assets.xcassets/Theme/OnTint.colorset/Contents.json")
      .replacingOccurrences(of: " ", with: "")

    guard let darkRange = json.range(of: "\"luminosity\"") else {
      return XCTFail("OnTint must declare a dark appearance variant.")
    }
    let light = String(json[..<darkRange.lowerBound])
    let dark = String(json[darkRange.lowerBound...])

    XCTAssertTrue(light.contains("\"red\":\"0xFF\""), "OnTint light must be white on the deep light-mode gold.")
    XCTAssertTrue(dark.contains("\"red\":\"0x0A\""), "OnTint dark must be Obsidian — white on #D8B477 is 1.96:1.")
  }

  func testSplashUsesNorviqLockupAndTaglineNotTheMascot() async throws {
    await Task.yield()
    let splash = try source("financeplan/Features/Launch/SplashScreen.swift")
    let logo = try source("financeplan/Features/Auth/NorviqaLogo.swift")

    XCTAssertTrue(
      splash.contains("NorviqFullLogo"),
      "The load screen must show the Norviq lockup from Assets."
    )
    XCTAssertTrue(
      splash.contains("Discipline creates freedom."),
      "The load screen tagline is the Precision line, set as live text."
    )
    XCTAssertFalse(
      splash.contains("Vig"),
      "Vig is content art. The load screen carries the Norviq lockup alone."
    )
    XCTAssertFalse(
      splash.contains("The vigil begins."),
      "Vigil copy is retired."
    )
    XCTAssertFalse(
      splash.contains("RadialGradient") || splash.contains(".shadow("),
      "The Precision splash has no glow."
    )
    XCTAssertTrue(
      logo.contains("Image(\"NorviqIcon\")"),
      "NorviqLogo is the ring-and-star mark, not the mascot."
    )
    XCTAssertFalse(
      logo.contains("Vig"),
      "The shared logo component must not render the mascot."
    )
  }

  func testLaunchScreenBackgroundAdaptsToAppearance() async throws {
    await Task.yield()
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
    XCTAssertTrue(
      colorset.contains("\"value\" : \"dark\""),
      "LaunchBackground needs a dark variant or the launch screen cannot adapt."
    )
  }

  // MARK: - Dead navigation

  func testNoPlaceholderSettingsDestinationsRemain() async throws {
    await Task.yield()
    let src = try source("financeplan/Features/UserProfile/UserProfileView.swift")

    // .dataHandling and .sensitiveActions had no push sites anywhere, so they
    // were unreachable enum cases whose bodies were bare Text placeholders.
    XCTAssertFalse(
      src.contains("Text(\"Data handling\")"),
      "unreachable placeholder destination should be removed, not shipped"
    )
    XCTAssertFalse(
      src.contains("Text(\"Sensitive actions\")"),
      "unreachable placeholder destination should be removed, not shipped"
    )
    XCTAssertFalse(src.contains("case dataHandling"))
    XCTAssertFalse(src.contains("case sensitiveActions"))
  }

  func testBankSyncStaysReachableFromSettingsInTwoTaps() async throws {
    await Task.yield()
    let profile = try source("financeplan/Features/UserProfile/UserProfileView.swift")
    let integrations = try source("financeplan/Features/Integrations/IntegrationsView.swift")

    // Settings > Connected Accounts > Bank Sync. PR #60 had to restore this
    // entry once; keep the shallow path intact.
    XCTAssertTrue(
      profile.contains("UserProfileDestination.integrations"),
      "Settings must keep a direct row to the functional integrations screen"
    )
    XCTAssertTrue(
      integrations.contains("BankingView()"),
      "bank sync must stay reachable from IntegrationsView"
    )
  }

  // MARK: - Card surfaces

  func testGlassCardKeepsAdaptiveDefaultPadding() async throws {
    await Task.yield()
    let src = try source("financeplan/Components/GlassCard.swift")

    // `.padding()` and `.padding(16)` are NOT equivalent — the no-argument form
    // is adaptive. All 75 existing call sites render the adaptive one, so the
    // nil branch must keep calling it with no argument.
    XCTAssertTrue(
      src.contains("content.padding()"),
      "the default padding branch must stay adaptive, not a fixed value"
    )
    XCTAssertTrue(
      src.contains("padding: CGFloat? = nil"),
      "padding must be opt-in so existing call sites are unaffected"
    )
  }

  func testGlassCardStillAppliesAppGlassEffect() async throws {
    await Task.yield()
    let src = try source("financeplan/Components/GlassCard.swift")

    // Guards the consolidation trap: pointing GlassCard at VigilGlassBackground
    // would drop .appGlassEffect and leave a flat cardBackground fill with no
    // stroke, shadow or native glass, flattening cards across all 75 sites. Any
    // future change here needs a screenshot review first.
    XCTAssertTrue(
      src.contains(".appGlassEffect("),
      "GlassCard must keep the native/fallback glass primitive"
    )

    // Match construction, not any mention: the doc comment in that file
    // deliberately names VigilGlassBackground to explain why it is NOT used.
    XCTAssertFalse(
      src.contains("VigilGlassBackground("),
      "swapping in VigilGlassBackground flattens the cards; needs visual review"
    )
  }

  // MARK: - Tab bar chrome

  /// The app used to hide the native tab bar process-wide and draw its own
  /// floating capsule. That cost iPad sidebar adaptation, the accessibility
  /// rotor, scroll-edge behaviour and correct safe-area handling, and the
  /// capsule overflowed at the *default* Dynamic Type size.
  ///
  /// Re-hiding the bar is the one edit that would silently undo all of it, so it
  /// is what this guards.
  func testNativeTabBarIsNotHiddenAgain() async throws {
    await Task.yield()
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

  /// Home is content + system chrome. Command-center kickers, a second net-worth
  /// strip, and bordered toolbar blobs are the LLM glass look this screen dropped.
  func testHomeDropsCommandCenterTheater() async throws {
    await Task.yield()
    let dashboard = try source("financeplan/Features/Home/DashboardRoot.swift")
    XCTAssertFalse(
      dashboard.contains("VigilPageHeader"),
      "Home uses the system large title, not an Intelligence eyebrow."
    )
    XCTAssertFalse(
      dashboard.contains("VigilCommandMetricsBar"),
      "The metrics strip duplicated net worth and shipped an AGENTIC pill."
    )
    XCTAssertFalse(
      dashboard.contains("AGENTIC"),
      "Home must not advertise AGENTIC chrome."
    )
    XCTAssertTrue(
      dashboard.contains("navigationTitle(greetingText)"),
      "Greeting belongs in the system navigation title."
    )
    XCTAssertFalse(
      dashboard.contains(".buttonStyle(.bordered"),
      "Toolbar items should be system symbols, not bordered glass blobs."
    )
    XCTAssertTrue(
      dashboard.contains("placement: .primaryAction"),
      "Capture expense is the one prominent toolbar action."
    )

    let why = try source("financeplan/Features/Home/WhyMovedCard.swift")
    XCTAssertFalse(why.contains("AGENTIC"), "Why-it-moved copy must stay plain language.")
    XCTAssertFalse(why.contains("GlassCard"), "Why-it-moved is content, not a glass card.")

    let feed = try source("financeplan/Features/Home/UnifiedActivityFeed.swift")
    XCTAssertFalse(feed.contains("GlassCard"), "Activity rows sit on the page, not in glass cards.")
  }


  // MARK: - Credential autofill

  func testEveryCodeEntryFieldOffersOneTimeCodeAutofill() async throws {
    await Task.yield()
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

  func testCredentialFieldsDeclareTheirContentType() async throws {
    await Task.yield()
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

  func testOnboardingAnimationsRespectReduceMotion() async throws {
    await Task.yield()
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

  @MainActor
  func testPaywallCatalogMatchesPaidFeaturesAndKeepsReportsFree() async {
    await Task.yield()
    let ids = Set(PaywallCatalog.rows.map(\.id))
    for key in [
      "broker_sync", "target_alerts", "market_fundamentals", "valuation_cases",
      "scenario_planning", "net_worth_forecasting", "smart_screening",
      "rebalancing_rules", "advanced_portfolios", "crypto", "bank_sync",
      "receipt_scan", "household_partner", "recurring_templates", "year_overview",
      "smart_suggestions", "ai_insights", "mcp_access", "tax_optimization",
      "advanced_report_runs",
    ] {
      XCTAssertTrue(ids.contains(key), "catalog missing Pro feature \(key)")
      XCTAssertFalse(
        PaywallCatalog.rows.first { $0.id == key }?.includedInFree ?? true,
        "\(key) must not be sold as Free"
      )
    }

    let reports = PaywallCatalog.rows.first { $0.id == "reports" }
    XCTAssertEqual(reports?.includedInFree, true)
    XCTAssertEqual(reports?.includedInPro, true)
  }

  func testPaywallScreensNoLongerAdvertiseBannedCopy() async throws {
    await Task.yield()
    for path in [
      "financeplan/Features/UserProfile/PaywallView.swift",
      "financeplan/Features/Auth/PreLoginPaywallScreen.swift",
      "financeplan/Features/Onboarding/Questionnaire/Screens/OnboardingQuestionnairePaywallScreen.swift",
    ] {
      let src = try source(path)
      XCTAssertFalse(src.contains("Unlimited Syncing"), "\(path) still sells Unlimited Syncing")
      XCTAssertFalse(src.contains("Real-time Market Data"), "\(path) still sells Real-time Market Data")
      XCTAssertTrue(src.contains("PaywallComparisonTable"), "\(path) must render the shared catalog")
    }
  }

  func testAllThreePaywallEntryPointsDiscloseTerms() async throws {
    await Task.yield()
    // Every entry point must independently show price, cancellation and trial
    // terms — a user can reach any one of them without seeing the others.
    for path in [
      "financeplan/Features/UserProfile/PaywallView.swift",
      "financeplan/Features/Auth/PreLoginPaywallScreen.swift",
      "financeplan/Features/Onboarding/Questionnaire/Screens/OnboardingQuestionnairePaywallScreen.swift",
    ] {
      let src = try source(path)
      XCTAssertTrue(
        src.contains("PaywallTrustStrip"),
        "\(path) must show the cancellation and trial-charge strip"
      )
      XCTAssertTrue(
        src.contains("localizedPriceString"),
        "\(path) must show the real StoreKit price, not a hardcoded one"
      )
    }
  }

  func testPaywallPriceCannotBeTruncatedAtLargeDynamicType() async throws {
    await Task.yield()
    let card = try source("financeplan/Components/Paywall/PaywallPlanCard.swift")

    // The card is a horizontal HStack: the title/subtitle column and the price
    // compete for width. At AX5 SwiftUI truncates whichever side loses, and on a
    // paywall that must never be the price. Build-31 was rejected for exactly
    // this class of Dynamic Type failure.
    XCTAssertTrue(
      card.contains(".layoutPriority(1)"),
      "the price column must win the width negotiation"
    )
    XCTAssertTrue(
      card.contains(".fixedSize(horizontal: true, vertical: false)"),
      "the price must not compress"
    )
    XCTAssertTrue(
      card.contains(".fixedSize(horizontal: false, vertical: true)"),
      "the title and subtitle must wrap rather than squeeze the price out"
    )

    let strip = try source("financeplan/Components/Paywall/PaywallTrustStrip.swift")
    XCTAssertTrue(
      strip.contains(".fixedSize(horizontal: false, vertical: true)"),
      "three equal columns at AX5 must wrap, not truncate \"Charged after trial\""
    )
  }
}

