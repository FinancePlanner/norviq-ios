import SwiftUI

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
    // MARK: - Accent (classic blue / Vigil neon cyan)

    static func tint(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        scheme == .dark
          ? Color(red: 0.36, green: 0.67, blue: 0.98) // #5CABFA
          : Color(red: 0.00, green: 0.48, blue: 1.00) // #007AFF
      case .vigil:
        scheme == .dark
          ? Color(red: 0.000, green: 0.949, blue: 1.000) // #00F2FF
          : Color(red: 0.031, green: 0.569, blue: 0.698) // #0891B2
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
          ? Color(red: 0.000, green: 0.949, blue: 1.000).opacity(0.10)
          : Color(red: 0.878, green: 0.969, blue: 0.980) // #E0F7FA
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
          ? Color(red: 0.000, green: 1.000, blue: 0.580) // #00FF94
          : Color(red: 0.051, green: 0.580, blue: 0.533) // #0D9488
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
          ? Color(red: 0.404, green: 0.965, blue: 1.000) // #67F6FF
          : Color(red: 0.024, green: 0.714, blue: 0.831) // #06B6D4
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
          ? Color(red: 0.000, green: 0.722, blue: 0.769) // #00B8C4
          : Color(red: 0.055, green: 0.455, blue: 0.565) // #0E7490
      }
    }

    // MARK: - Surfaces (classic cool / Vigil near-black command center)

    static func pageBackground(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        scheme == .dark
          ? Color(red: 0.06, green: 0.07, blue: 0.10)
          : Color(red: 0.95, green: 0.96, blue: 0.98)
      case .vigil:
        scheme == .dark
          ? Color(red: 0.020, green: 0.020, blue: 0.020) // #050505
          : Color(red: 0.933, green: 0.965, blue: 0.973) // #EEF6F8
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
          ? Color(red: 0.039, green: 0.067, blue: 0.086) // #0A1116
          : Color(red: 0.969, green: 0.988, blue: 0.992) // #F7FCFD
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
          ? Color(red: 0.059, green: 0.102, blue: 0.129) // #0F1A21
          : Color(red: 0.886, green: 0.933, blue: 0.949) // #E2EEF2
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
          ? Color(red: 0.027, green: 0.051, blue: 0.067) // #070D11
          : Color(red: 0.957, green: 0.980, blue: 0.984) // #F4FAFB
      }
    }

    // MARK: - Text (classic cool slate / Vigil cool cyan-slate)

    static func foreground(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        scheme == .dark
          ? Color(red: 0.93, green: 0.95, blue: 0.97) // cool near-white
          : Color(red: 0.09, green: 0.11, blue: 0.15) // cool slate near-black
      case .vigil:
        scheme == .dark
          ? Color(red: 0.843, green: 0.965, blue: 0.980) // #D7F6FA
          : Color(red: 0.043, green: 0.110, blue: 0.133) // #0B1C22
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
          ? Color(red: 0.498, green: 0.604, blue: 0.639) // #7F9AA3
          : Color(red: 0.294, green: 0.396, blue: 0.439) // #4B6570
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
          ? Color(red: 0.420, green: 0.486, blue: 0.525) // muted cyan-slate
          : Color(red: 0.420, green: 0.486, blue: 0.525)
      }
    }

    static func tertiaryFill(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color.white.opacity(0.08)
        : Color.black.opacity(0.05)
    }

    static func separator(for scheme: ColorScheme) -> Color {
      switch BrandTheme.current {
      case .classic:
        return scheme == .dark
          ? Color.white.opacity(0.10)
          : Color.black.opacity(0.10)
      case .vigil:
        return scheme == .dark
          ? Color(red: 0.000, green: 0.949, blue: 1.000).opacity(0.18)
          : Color(red: 0.031, green: 0.569, blue: 0.698).opacity(0.22)
      }
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

    // MARK: - Overlays

    static let scrim = Color.black.opacity(0.5)

    static var splashRing: Color {
      switch BrandTheme.current {
      case .classic:
        Color.blue.opacity(0.25)
      case .vigil:
        Color(red: 0.000, green: 0.949, blue: 1.000).opacity(0.30) // cyan
      }
    }

    static var splashCore: Color {
      switch BrandTheme.current {
      case .classic:
        Color.teal.opacity(0.8)
      case .vigil:
        Color(red: 0.000, green: 1.000, blue: 0.580).opacity(0.75) // emerald
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
        Colors.tint(for: scheme).opacity(scheme == .dark ? 0.9 : 0.8),
        Colors.secondaryTint(for: scheme).opacity(scheme == .dark ? 0.85 : 0.75)
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
        return [
          Color(red: 0.05, green: 0.08, blue: 0.14),
          Color(red: 0.03, green: 0.04, blue: 0.08)
        ]
      case .light:
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
        // Near-black → deep cyan well → emerald bloom.
        return [
          Color(red: 0.020, green: 0.020, blue: 0.020), // #050505
          Color(red: 0.020, green: 0.090, blue: 0.120),
          Color(red: 0.000, green: 0.949, blue: 1.000).opacity(0.28)
        ]
      case .light:
        return [
          Color(red: 0.933, green: 0.965, blue: 0.973), // #EEF6F8
          Color(red: 0.878, green: 0.969, blue: 0.980) // #E0F7FA
        ]
      @unknown default:
        return [
          Color(red: 0.020, green: 0.020, blue: 0.020),
          Color(red: 0.020, green: 0.090, blue: 0.120),
          Color(red: 0.000, green: 0.949, blue: 1.000).opacity(0.28)
        ]
      }
    }
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
