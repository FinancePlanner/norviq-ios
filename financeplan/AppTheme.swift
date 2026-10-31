import SwiftUI
import UIKit

// MARK: - Brand + Appearance

enum AppAppearance: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  static let storageKey = "app_appearance"

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .system:
      "System"
    case .light:
      "Light"
    case .dark:
      "Dark"
    }
  }

  var subtitle: LocalizedStringKey {
    switch self {
    case .system:
      "Follow your device appearance."
    case .light:
      "Always use light appearance."
    case .dark:
      "Always use dark appearance."
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system:
      nil
    case .light:
      .light
    case .dark:
      .dark
    }
  }

  static func from(_ rawValue: String) -> AppAppearance {
    AppAppearance(rawValue: rawValue) ?? .system
  }
}

enum AppTheme {
  enum Radius {
    static let control: CGFloat = 12
    static let card: CGFloat = 16
    static let hero: CGFloat = 20
  }

  enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
  }

  enum Colors {
    // MARK: - Palette
    //
    // Every role below resolves from `Assets.xcassets/Theme`, so each colour is a
    // dynamic UIColor that adapts to the trait collection on its own. That is what
    // makes light mode work without threading `\.colorScheme` through 121 view
    // files — see the deprecated shims at the bottom of this enum.

    /// The "Vigil" prefix is not vestigial brand-switching: bare role names make
    /// the asset catalog generate `Color.tint`, `Color.separator` and friends,
    /// which collide with SwiftUI's own `ShapeStyle` members and make every
    /// `foregroundStyle(.tint)` in the app ambiguous.
    nonisolated private static func themeColor(_ role: String) -> Color {
      Color("Vigil\(role)", bundle: .main)
    }

    // MARK: - Accent (Precision gold — docs/precision-identity.md)
    //
    // Gold is brand, never money: it marks the primary action, selection and
    // focus. Gains and losses use `gain` / `loss` below and nothing else.

    static var tint: Color { themeColor("Tint") }
    static var tintSoft: Color { themeColor("TintSoft") }
    static var secondaryTint: Color { themeColor("SecondaryTint") }

    /// Near-duplicate of `secondaryTint` — folded into it rather than carrying
    /// a fourth near-identical hue per brand/scheme.
    static var ember: Color { secondaryTint }

    /// Near-duplicate of `secondaryTint` — folded into it rather than carrying
    /// a fourth near-identical hue per brand/scheme.
    static var bronze: Color { secondaryTint }

    /// Foreground for content sitting ON the accent tint.
    ///
    /// White fails on the dark tint: champagne gold `#D8B477` carries white at
    /// only **1.96:1**, while obsidian ink on it measures 9.7:1.
    ///
    /// Light and dark therefore invert: the light tint (deep gold `#80612A`) is
    /// dark enough to carry white (5.7:1), the dark tint is far too bright to.
    /// This mirrors the web's `--primary-foreground`, which encodes the same
    /// inversion in `theme.css`.
    static let onTint = Color("OnTint", bundle: .main)

    // MARK: - Surfaces (obsidian / midnight navy / armor blue; warm paper in light)

    static var pageBackground: Color { themeColor("PageBackground") }
    static var cardBackground: Color { themeColor("CardBackground") }
    static var elevatedCardBackground: Color { themeColor("ElevatedCard") }
    static var topBarBackground: Color { themeColor("TopBarBackground") }

    // MARK: - Text (platinum / muted silver; deep navy in light)

    static var foreground: Color { themeColor("Foreground") }
    static var secondaryText: Color { themeColor("SecondaryText") }
    static var tertiaryText: Color { themeColor("TertiaryText") }

    // MARK: - Lines and fills

    static let tertiaryFill = Color("TertiaryFill", bundle: .main)

    /// The hairline token from `docs/precision-identity.md` (Steel Slate in dark).
    ///
    /// Decorative only — well under 3:1 by design. It is the hairline on every
    /// card, and `GlassEffect+Compat` reuses it as the pre-iOS-26 glass stroke, so
    /// keep it neutral: a tinted separator shows up twice on most surfaces.
    static var separator: Color { themeColor("Separator") }

    // MARK: - Nav bar

    static var navBarBackground: Color { topBarBackground }

    static var navBarForeground: Color { .primary }

    static var tabBarBackground: Color { topBarBackground }

    // MARK: - Financial semantics
    //
    // Direction of money only — never decoration, never brand. Each is >= 4.5:1
    // as text on its own appearance's page and card (measured in the brand doc).
    // Always pair with a sign, arrow or accessibility label: never colour alone.

    // nonisolated: plain asset lookups, so model and formatter code outside the
    // main actor can pick a direction colour too.
    nonisolated static var gain: Color { themeColor("Gain") }
    nonisolated static var loss: Color { themeColor("Loss") }
    nonisolated static var flat: Color { themeColor("Flat") }
    nonisolated static var info: Color { themeColor("Info") }

    // MARK: - Status

    nonisolated static var success: Color { gain }
    nonisolated static var danger: Color { loss }
    nonisolated static var warning: Color { themeColor("Warning") }
    static let disabled = Color.gray.opacity(0.65)

    /// Text-safe variants. The colour sets already adapt to light/dark, so these
    /// return the same dynamic colour for either scheme; the parameter stays so
    /// the existing call sites compile unchanged.
    static func dangerText(for _: ColorScheme) -> Color { loss }

    static func successText(for _: ColorScheme) -> Color { gain }

    static func warningText(for _: ColorScheme) -> Color { warning }

    // MARK: - UIKit bridge
    //
    // `UIColor(someDynamicColor)` resolves against whatever trait collection is
    // current at the moment it is called and freezes the result, which is exactly
    // wrong for the appearance proxies (they are configured once, off-screen, and
    // then applied globally). Resolving the named asset directly keeps the UIColor
    // dynamic, so UIKit chrome follows light/dark on its own.

    private static func themeUIColor(_ role: String) -> UIColor {
      UIColor(named: "Vigil\(role)") ?? .clear
    }

    static var uiTopBarBackground: UIColor { themeUIColor("TopBarBackground") }
    static var uiNavBarBackground: UIColor { uiTopBarBackground }
    static var uiForeground: UIColor { themeUIColor("Foreground") }
    static var uiSeparator: UIColor { themeUIColor("Separator") }
    static var uiOnTint: UIColor { UIColor(named: "OnTint") ?? .label }

    // MARK: - Deprecated scheme-taking shims
    //
    // The colours above are dynamic, so the scheme argument no longer does
    // anything. These overloads exist purely so the ~236 existing call sites keep
    // compiling untouched; the deprecation warnings are the cleanup backlog.
    //
    // Delete a shim once its call sites are gone — do not add new ones.

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.tint.")
    static func tint(for _: ColorScheme) -> Color { tint }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.tintSoft.")
    static func tintSoft(for _: ColorScheme) -> Color { tintSoft }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.secondaryTint.")
    static func secondaryTint(for _: ColorScheme) -> Color { secondaryTint }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.ember.")
    static func ember(for _: ColorScheme) -> Color { ember }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.bronze.")
    static func bronze(for _: ColorScheme) -> Color { bronze }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.pageBackground.")
    static func pageBackground(for _: ColorScheme) -> Color { pageBackground }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.cardBackground.")
    static func cardBackground(for _: ColorScheme) -> Color { cardBackground }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.elevatedCardBackground.")
    static func elevatedCardBackground(for _: ColorScheme) -> Color { elevatedCardBackground }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.topBarBackground.")
    static func topBarBackground(for _: ColorScheme) -> Color { topBarBackground }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.foreground.")
    static func foreground(for _: ColorScheme) -> Color { foreground }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.secondaryText.")
    static func secondaryText(for _: ColorScheme) -> Color { secondaryText }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.tertiaryText.")
    static func tertiaryText(for _: ColorScheme) -> Color { tertiaryText }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.tertiaryFill.")
    static func tertiaryFill(for _: ColorScheme) -> Color { tertiaryFill }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.separator.")
    static func separator(for _: ColorScheme) -> Color { separator }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.navBarBackground.")
    static func navBarBackground(for _: ColorScheme) -> Color { navBarBackground }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.navBarForeground.")
    static func navBarForeground(for _: ColorScheme) -> Color { navBarForeground }

    @available(*, deprecated, message: "Colours are dynamic; use AppTheme.Colors.tabBarBackground.")
    static func tabBarBackground(for _: ColorScheme) -> Color { tabBarBackground }

    // MARK: - Overlays

    static let scrim = Color.black.opacity(0.5)

    // MARK: - Premium / Paywall

    static func premiumGradient(for scheme: ColorScheme) -> LinearGradient {
      LinearGradient(
        colors: premiumGradientColors(for: scheme),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }

    static func premiumGradientColors(for scheme: ColorScheme) -> [Color] {
      [tint(for: scheme), secondaryTint(for: scheme)]
    }
  }

  static func avatarGradient(for scheme: ColorScheme) -> [Color] {
    [
      Colors.tint(for: scheme).opacity(scheme == .dark ? 0.9 : 0.8),
      Colors.secondaryTint(for: scheme).opacity(scheme == .dark ? 0.85 : 0.75)
    ]
  }
}

// MARK: - Vigil glass surface
//
// VigilGlassBackground and .vigilGlassCard() were retired here: every call site
// now goes through GlassCard, which resolves through appGlassEffect for both
// brands (native .glassEffect on iOS 26, a fill+stroke+shadow fallback below
// it) instead of this hand-rolled ultraThinMaterial recipe. See GlassCard.swift.

extension View {
  /// Monospaced kicker label used for WATCH / MCP / command headers.
  func vigilOverline() -> some View {
    self
      .font(.caption2.weight(.bold).monospaced())
      .tracking(1.2)
      .textCase(.uppercase)
  }
}
