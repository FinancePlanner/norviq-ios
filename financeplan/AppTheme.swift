import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  static let storageKey = "app_appearance"

  var id: String { rawValue }

  var title: String {
    switch self {
    case .system:
      "System"
    case .light:
      "Light"
    case .dark:
      "Dark"
    }
  }

  var subtitle: String {
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
  enum Colors {
    // MARK: - Accent

    static func tint(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.36, green: 0.67, blue: 0.98)
        : Color(red: 0.00, green: 0.48, blue: 1.00)
    }

    static func tintSoft(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.15, green: 0.18, blue: 0.24)
        : Color(red: 0.92, green: 0.95, blue: 1.00)
    }

    static func secondaryTint(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.35, green: 0.82, blue: 0.80)
        : Color(red: 0.04, green: 0.63, blue: 0.67)
    }

    // MARK: - Surfaces

    static func pageBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.06, green: 0.07, blue: 0.10)
        : Color(red: 0.95, green: 0.96, blue: 0.98)
    }

    static func cardBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.10, green: 0.11, blue: 0.15)
        : Color.white
    }

    static func elevatedCardBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.14, green: 0.16, blue: 0.20)
        : Color(red: 0.93, green: 0.94, blue: 0.97)
    }

    static func topBarBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.08, green: 0.09, blue: 0.12)
        : Color(red: 0.98, green: 0.99, blue: 1.00)
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
    static let splashRing = Color.blue.opacity(0.25)
    static let splashCore = Color.teal.opacity(0.8)
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

  static func splashGradient(for scheme: ColorScheme) -> [Color] {
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
  }
}
