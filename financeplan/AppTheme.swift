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

enum BrandTheme: String, CaseIterable, Identifiable {
  case classic
  case vigil

  static let storageKey = "app_brand_theme"

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .classic:
      "Classic"
    case .vigil:
      "Vigil"
    }
  }

  var subtitle: LocalizedStringKey {
    switch self {
    case .classic:
      "The original blue and teal palette."
    case .vigil:
      "Neon command center — cyan and emerald on near-black."
    }
  }

  static func from(_ rawValue: String) -> BrandTheme {
    // Empty / unknown storage defaults to Vigil (Command Center).
    if rawValue.isEmpty { return .vigil }
    return BrandTheme(rawValue: rawValue) ?? .vigil
  }

  /// The currently selected brand theme, read from UserDefaults.
  /// Views re-render on change via the root `.id(brandThemeRawValue)` in `NorviqApp`.
  static var current: BrandTheme {
    from(UserDefaults.standard.string(forKey: storageKey) ?? "")
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
    //
    // The brand still has to be picked in Swift: a colorset carries light/dark
    // appearance variants, but has no notion of Classic vs Vigil.

    private static func brandColor(_ role: String) -> Color {
      Color("\(BrandTheme.current == .vigil ? "Vigil" : "Classic")\(role)", bundle: .main)
    }

    // MARK: - Accent (classic blue / Vigil neon cyan)

    static var tint: Color { brandColor("Tint") }
    static var tintSoft: Color { brandColor("TintSoft") }
    static var secondaryTint: Color { brandColor("SecondaryTint") }

    /// Near-duplicate of `secondaryTint` — folded into it rather than carrying
    /// a fourth near-identical hue per brand/scheme.
    static var ember: Color { secondaryTint }

    /// Near-duplicate of `secondaryTint` — folded into it rather than carrying
    /// a fourth near-identical hue per brand/scheme.
    static var bronze: Color { secondaryTint }

    /// Foreground for content sitting ON the accent tint.
    ///
    /// White fails badly here. The Vigil dark tint is `#00F2FF`, a near-maximally
    /// bright cyan, so white-on-tint measures **1.39:1** — below even the 3:1
    /// large-text floor. Dark ink on the same fill measures ~12.9:1.
    ///
    /// Light and dark therefore invert: the light tint is dark enough to carry
    /// white, the dark tint is far too bright to. This mirrors the web's
    /// `--primary-foreground`, which already encodes exactly this inversion
    /// (`theme.css:136/227/318/404`).
    ///
    /// Not a brand change — docs/vigil-identity.md pins the tint itself, not what
    /// sits on top of it.
    static let onTint = Color("OnTint", bundle: .main)

    // MARK: - Surfaces (classic cool / Vigil near-black command center)

    static var pageBackground: Color { brandColor("PageBackground") }
    static var cardBackground: Color { brandColor("CardBackground") }
    static var elevatedCardBackground: Color { brandColor("ElevatedCard") }
    static var topBarBackground: Color { brandColor("TopBarBackground") }

    // MARK: - Text (classic cool slate / Vigil cool cyan-slate)

    static var foreground: Color { brandColor("Foreground") }
    static var secondaryText: Color { brandColor("SecondaryText") }
    static var tertiaryText: Color { brandColor("TertiaryText") }

    // MARK: - Lines and fills

    static let tertiaryFill = Color("TertiaryFill", bundle: .main)

    /// The `border` token from `docs/vigil-identity.md`.
    ///
    /// This used to be neon cyan at 18% opacity, which was drift from the spec
    /// and the single largest source of ambient blue: it is the hairline on every
    /// card, and `GlassEffect+Compat` reuses it as the pre-iOS-26 glass stroke, so
    /// most surfaces picked up the tint twice.
    static var separator: Color { brandColor("Separator") }

    // MARK: - Nav bar

    static var navBarBackground: Color { topBarBackground }

    static var navBarForeground: Color { .primary }

    static var tabBarBackground: Color { topBarBackground }

    // MARK: - Status

    static let success = Color.green
    static let danger = Color.red
    static let warning = Color.orange
    static let disabled = Color.gray.opacity(0.65)

    static func dangerText(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        return scheme == .dark
          ? Color(red: 1.0, green: 0.60, blue: 0.55)
          : Color.red
      case .vigil:
        return scheme == .dark
          ? Color(red: 1.0, green: 0.302, blue: 0.427) // #FF4D6D
          : Color(red: 0.86, green: 0.15, blue: 0.28)
      }
    }

    static func successText(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        return scheme == .dark
          ? Color(red: 0.65, green: 0.95, blue: 0.68)
          : Color.green
      case .vigil:
        return scheme == .dark
          ? Color(red: 0.000, green: 1.000, blue: 0.580) // #00FF94
          : Color(red: 0.020, green: 0.588, blue: 0.412)
      }
    }

    static func warningText(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 1.0, green: 0.80, blue: 0.42)
        : Color.orange
    }

    // MARK: - UIKit bridge
    //
    // `UIColor(someDynamicColor)` resolves against whatever trait collection is
    // current at the moment it is called and freezes the result, which is exactly
    // wrong for the appearance proxies (they are configured once, off-screen, and
    // then applied globally). Resolving the named asset directly keeps the UIColor
    // dynamic, so UIKit chrome follows light/dark on its own.

    private static func brandUIColor(_ role: String) -> UIColor {
      UIColor(named: "\(BrandTheme.current == .vigil ? "Vigil" : "Classic")\(role)") ?? .clear
    }

    static var uiTopBarBackground: UIColor { brandUIColor("TopBarBackground") }
    static var uiNavBarBackground: UIColor { uiTopBarBackground }
    static var uiForeground: UIColor { brandUIColor("Foreground") }
    static var uiSeparator: UIColor { brandUIColor("Separator") }
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

  static func heroGradient(for scheme: ColorScheme) -> [Color] {
    [
      Colors.tintSoft(for: scheme),
      Colors.pageBackground(for: scheme)
    ]
  }

  /// Flat 2-stop wash from page background to card background — same shape
  /// for both brands, only the underlying colors (and therefore hue) differ.
  static func splashGradient(for scheme: ColorScheme) -> [Color] {
    [
      Colors.pageBackground(for: scheme),
      Colors.cardBackground(for: scheme)
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
