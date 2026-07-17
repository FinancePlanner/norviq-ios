import SwiftUI

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
      "Molten gold on obsidian and ivory."
    }
  }

  static func from(_ rawValue: String) -> BrandTheme {
    BrandTheme(rawValue: rawValue) ?? .classic
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
    // MARK: - Accent (classic blue / Vigil molten gold)

    static func tint(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        scheme == .dark
          ? Color(red: 0.36, green: 0.67, blue: 0.98) // #5CABFA
          : Color(red: 0.00, green: 0.48, blue: 1.00) // #007AFF
      case .vigil:
        scheme == .dark
          ? Color(red: 0.910, green: 0.639, blue: 0.239) // #E8A33D
          : Color(red: 0.561, green: 0.369, blue: 0.110) // #8F5E1C
      }
    }

    static func tintSoft(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        scheme == .dark
          ? Color(red: 0.15, green: 0.18, blue: 0.24)
          : Color(red: 0.92, green: 0.95, blue: 1.00)
      case .vigil:
        scheme == .dark
          ? Color(red: 0.910, green: 0.639, blue: 0.239).opacity(0.14) // gold @ 14%
          : Color(red: 0.961, green: 0.918, blue: 0.827) // #F5EAD3
      }
    }

    static func secondaryTint(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        scheme == .dark
          ? Color(red: 0.35, green: 0.82, blue: 0.80) // teal
          : Color(red: 0.04, green: 0.63, blue: 0.67) // teal
      case .vigil:
        scheme == .dark
          ? Color(red: 0.690, green: 0.502, blue: 0.227) // #B0803A
          : Color(red: 0.427, green: 0.310, blue: 0.114) // #6D4F1D
      }
    }

    static func ember(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        // Classic maps ember to the original teal secondary-tint family.
        scheme == .dark
          ? Color(red: 0.35, green: 0.82, blue: 0.80) // teal
          : Color(red: 0.04, green: 0.63, blue: 0.67) // teal
      case .vigil:
        scheme == .dark
          ? Color(red: 0.941, green: 0.698, blue: 0.329) // #F0B254
          : Color(red: 0.788, green: 0.478, blue: 0.169) // #C97A2B
      }
    }

    static func bronze(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        // Classic maps bronze to a deeper teal/blue.
        scheme == .dark
          ? Color(red: 0.22, green: 0.58, blue: 0.60) // deep teal
          : Color(red: 0.02, green: 0.44, blue: 0.48) // deep teal
      case .vigil:
        scheme == .dark
          ? Color(red: 0.690, green: 0.502, blue: 0.227) // #B0803A
          : Color(red: 0.427, green: 0.310, blue: 0.114) // #6D4F1D
      }
    }

    // MARK: - Surfaces (classic cool / Vigil obsidian & ivory marble)

    static func pageBackground(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        scheme == .dark
          ? Color(red: 0.06, green: 0.07, blue: 0.10)
          : Color(red: 0.95, green: 0.96, blue: 0.98)
      case .vigil:
        scheme == .dark
          ? Color(red: 0.047, green: 0.039, blue: 0.031) // #0C0A08
          : Color(red: 0.965, green: 0.949, blue: 0.918) // #F6F2EA
      }
    }

    static func cardBackground(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        scheme == .dark
          ? Color(red: 0.10, green: 0.11, blue: 0.15)
          : Color.white
      case .vigil:
        scheme == .dark
          ? Color(red: 0.090, green: 0.075, blue: 0.063) // #171310
          : Color(red: 1.000, green: 0.992, blue: 0.973) // #FFFDF8
      }
    }

    static func elevatedCardBackground(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        scheme == .dark
          ? Color(red: 0.14, green: 0.16, blue: 0.20)
          : Color(red: 0.93, green: 0.94, blue: 0.97)
      case .vigil:
        scheme == .dark
          ? Color(red: 0.118, green: 0.098, blue: 0.082) // #1E1915
          : Color(red: 0.937, green: 0.914, blue: 0.867) // #EFE9DD
      }
    }

    static func topBarBackground(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        scheme == .dark
          ? Color(red: 0.08, green: 0.09, blue: 0.12)
          : Color(red: 0.98, green: 0.99, blue: 1.00)
      case .vigil:
        scheme == .dark
          ? Color(red: 0.071, green: 0.063, blue: 0.051) // #12100D
          : Color(red: 0.984, green: 0.973, blue: 0.945) // #FBF8F1
      }
    }

    // MARK: - Text (classic cool slate / Vigil warm stone)

    static func foreground(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        scheme == .dark
          ? Color(red: 0.93, green: 0.95, blue: 0.97) // cool near-white
          : Color(red: 0.09, green: 0.11, blue: 0.15) // cool slate near-black
      case .vigil:
        scheme == .dark
          ? Color(red: 0.953, green: 0.933, blue: 0.894) // #F3EEE4
          : Color(red: 0.110, green: 0.098, blue: 0.090) // #1C1917
      }
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        scheme == .dark
          ? Color(red: 0.612, green: 0.639, blue: 0.686) // #9CA3AF (cool gray)
          : Color(red: 0.294, green: 0.333, blue: 0.388) // #4B5563 (cool gray)
      case .vigil:
        scheme == .dark
          ? Color(red: 0.659, green: 0.635, blue: 0.620) // #A8A29E (warm stone)
          : Color(red: 0.341, green: 0.325, blue: 0.306) // #57534E (warm stone)
      }
    }

    static func tertiaryText(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        scheme == .dark
          ? Color(red: 0.420, green: 0.447, blue: 0.502) // #6B7280 (cool gray)
          : Color(red: 0.420, green: 0.447, blue: 0.502) // #6B7280 (cool gray)
      case .vigil:
        scheme == .dark
          ? Color(red: 0.471, green: 0.443, blue: 0.424) // #78716C (warm stone)
          : Color(red: 0.471, green: 0.443, blue: 0.424) // #78716C (warm stone)
      }
    }

    static func tertiaryFill(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color.white.opacity(0.08)
        : Color.black.opacity(0.05)
    }

    static func separator(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color.white.opacity(0.10)
        : Color.black.opacity(0.10)
    }

    // MARK: - Nav bar

    static func navBarBackground(for scheme: ColorScheme) -> Color {
      topBarBackground(for: scheme)
    }

    static func navBarForeground(for scheme: ColorScheme) -> Color {
      .primary
    }

    static func tabBarBackground(for scheme: ColorScheme) -> Color {
      topBarBackground(for: scheme)
    }

    // MARK: - Status

    static let success = Color.green
    static let danger = Color.red
    static let warning = Color.orange
    static let disabled = Color.gray.opacity(0.65)

    static func dangerText(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 1.0, green: 0.60, blue: 0.55) // Lighter red for dark mode
        : Color.red
    }

    static func successText(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.65, green: 0.95, blue: 0.68) // Lighter green for dark mode
        : Color.green
    }

    static func warningText(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 1.0, green: 0.80, blue: 0.42) // Lighter orange for dark mode
        : Color.orange
    }

    // MARK: - Overlays

    static let scrim = Color.black.opacity(0.5)

    static var splashRing: Color {
      switch BrandTheme.current {
      case .classic:
        Color.blue.opacity(0.25)
      case .vigil:
        Color(red: 0.910, green: 0.639, blue: 0.239).opacity(0.25) // gold #E8A33D
      }
    }

    static var splashCore: Color {
      switch BrandTheme.current {
      case .classic:
        Color.teal.opacity(0.8)
      case .vigil:
        Color(red: 0.941, green: 0.698, blue: 0.329).opacity(0.8) // ember #F0B254
      }
    }

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
    switch BrandTheme.current {
    case .classic:
      [
        Colors.tint(for: scheme).opacity(scheme == .dark ? 0.9 : 0.8),
        Colors.secondaryTint(for: scheme).opacity(scheme == .dark ? 0.85 : 0.75)
      ]
    case .vigil:
      [
        Colors.bronze(for: scheme).opacity(scheme == .dark ? 0.9 : 0.8),
        Colors.ember(for: scheme).opacity(scheme == .dark ? 0.85 : 0.75)
      ]
    }
  }

  static func heroGradient(for scheme: ColorScheme) -> [Color] {
    [
      Colors.tintSoft(for: scheme),
      Colors.pageBackground(for: scheme)
    ]
  }

  static func splashGradient(for scheme: ColorScheme) -> [Color] {
    switch BrandTheme.current {
    case .classic:
      switch scheme {
      case .dark:
        // Deep cool navy fade.
        return [
          Color(red: 0.05, green: 0.08, blue: 0.14),
          Color(red: 0.03, green: 0.04, blue: 0.08)
        ]
      case .light:
        // Pale blue fade.
        return [
          Color(red: 0.95, green: 0.97, blue: 1.00),
          Color(red: 0.88, green: 0.93, blue: 0.99)
        ]
      @unknown default:
        return [
          Color(red: 0.05, green: 0.08, blue: 0.14),
          Color(red: 0.03, green: 0.04, blue: 0.08)
        ]
      }
    case .vigil:
      switch scheme {
      case .dark:
        // Warm obsidian → deep bronze → ember glow.
        return [
          Color(red: 0.047, green: 0.039, blue: 0.031), // #0C0A08
          Color(red: 0.227, green: 0.165, blue: 0.071), // #3A2A12
          Color(red: 0.788, green: 0.478, blue: 0.169).opacity(0.45) // ember #C97A2B
        ]
      case .light:
        // Ivory → soft gold.
        return [
          Color(red: 0.965, green: 0.949, blue: 0.918), // #F6F2EA
          Color(red: 0.961, green: 0.918, blue: 0.827) // #F5EAD3
        ]
      @unknown default:
        return [
          Color(red: 0.047, green: 0.039, blue: 0.031),
          Color(red: 0.227, green: 0.165, blue: 0.071),
          Color(red: 0.788, green: 0.478, blue: 0.169).opacity(0.45)
        ]
      }
    }
  }
}
