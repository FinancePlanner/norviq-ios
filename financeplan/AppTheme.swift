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
        ? Color(red: 0.20, green: 0.95, blue: 0.60)  // Neon Green
        : Color(red: 0.05, green: 0.40, blue: 0.95)  // Electric Blue
    }

    static func tintSoft(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.10, green: 0.25, blue: 0.18)  // Soft Neon Green
        : Color(red: 0.89, green: 0.94, blue: 1.00)  // Soft Electric Blue
    }

    // MARK: - Surfaces

    static func pageBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.04, green: 0.04, blue: 0.06)  // Deep Black-Blue
        : Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    static func cardBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.09, green: 0.09, blue: 0.12)  // Slightly elevated dark
        : Color(red: 1.00, green: 1.00, blue: 1.00)
    }

    static func elevatedCardBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.15, green: 0.15, blue: 0.20)  // Highest elevation
        : Color(red: 0.97, green: 0.97, blue: 0.98)
    }

    static func topBarBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.04, green: 0.04, blue: 0.06).opacity(0.8)  // Glass effect
        : Color(red: 1.00, green: 1.00, blue: 1.00).opacity(0.8)
    }

    static func tertiaryFill(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color.white.opacity(0.05)
        : Color.black.opacity(0.05)
    }

    // MARK: - Nav bar

    static func navBarBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.06, green: 0.06, blue: 0.09)
        : Color(red: 1.00, green: 1.00, blue: 1.00)
    }

    static func navBarForeground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.95, green: 0.95, blue: 0.97)
        : Color(red: 0.10, green: 0.10, blue: 0.14)
    }

    static func tabBarBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.06, green: 0.06, blue: 0.09)
        : Color(red: 1.00, green: 1.00, blue: 1.00)
    }

    // MARK: - Status

    static let success = Color(red: 0.20, green: 0.95, blue: 0.60)  // Neon Green
    static let danger = Color(red: 1.00, green: 0.25, blue: 0.40)  // Neon Pink/Red
    static let disabled = Color.gray.opacity(0.5)

    // MARK: - Overlays

    static let scrim = Color.black.opacity(0.5)
    static let splashRing = Color(red: 0.20, green: 0.95, blue: 0.60).opacity(0.4)
    static let splashCore = Color(red: 0.10, green: 0.85, blue: 0.50).opacity(0.9)
  }

  static func avatarGradient(for scheme: ColorScheme) -> [Color] {
    switch scheme {
    case .dark:
      return [
        Color(red: 0.60, green: 0.20, blue: 1.00),  // Neon Purple
        Color(red: 0.20, green: 0.50, blue: 1.00),  // Neon Blue
      ]
    case .light:
      return [
        Color(red: 0.40, green: 0.10, blue: 0.90),
        Color(red: 0.10, green: 0.40, blue: 0.90),
      ]
    @unknown default:
      return [
        Color(red: 0.40, green: 0.10, blue: 0.90),
        Color(red: 0.10, green: 0.40, blue: 0.90),
      ]
    }
  }

  static func heroGradient(for scheme: ColorScheme) -> [Color] {
    switch scheme {
    case .dark:
      return [
        Color(red: 0.20, green: 0.95, blue: 0.60).opacity(0.7),  // Neon Green
        Color(red: 0.20, green: 0.50, blue: 1.00).opacity(0.4),  // Neon Blue
      ]
    case .light:
      return [
        Color(red: 0.80, green: 0.95, blue: 1.00),
        Color(red: 0.70, green: 0.85, blue: 1.00),
      ]
    @unknown default:
      return [
        Color(red: 0.20, green: 0.95, blue: 0.60).opacity(0.7),
        Color(red: 0.20, green: 0.50, blue: 1.00).opacity(0.4),
      ]
    }
  }

  static func splashGradient(for scheme: ColorScheme) -> [Color] {
    switch scheme {
    case .dark:
      return [
        Color(red: 0.04, green: 0.05, blue: 0.08),
        Color(red: 0.02, green: 0.02, blue: 0.04),
      ]
    case .light:
      return [
        Color(red: 0.90, green: 0.95, blue: 1.00),
        Color(red: 0.80, green: 0.85, blue: 0.95),
      ]
    @unknown default:
      return [
        Color(red: 0.04, green: 0.05, blue: 0.08),
        Color(red: 0.02, green: 0.02, blue: 0.04),
      ]
    }
  }
}
