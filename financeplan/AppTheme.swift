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
        ? Color(red: 0.44, green: 0.69, blue: 1.00)
        : Color(red: 0.07, green: 0.34, blue: 0.79)
    }

    static func tintSoft(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.11, green: 0.16, blue: 0.24)
        : Color(red: 0.91, green: 0.95, blue: 1.00)
    }

    static func secondaryTint(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.39, green: 0.79, blue: 0.76)
        : Color(red: 0.07, green: 0.56, blue: 0.57)
    }

    // MARK: - Surfaces

    static func pageBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.05, green: 0.07, blue: 0.11)
        : Color(red: 0.96, green: 0.97, blue: 0.99)
    }

    static func cardBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.09, green: 0.11, blue: 0.16)
        : Color.white
    }

    static func elevatedCardBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.12, green: 0.15, blue: 0.20)
        : Color(red: 0.93, green: 0.95, blue: 0.98)
    }

    static func topBarBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? pageBackground(for: scheme).opacity(0.92)
        : Color.white.opacity(0.92)
    }

    static func tertiaryFill(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color.white.opacity(0.08)
        : Color.black.opacity(0.06)
    }

    static func separator(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color.white.opacity(0.08)
        : Color.black.opacity(0.08)
    }

    // MARK: - Nav bar

    static func navBarBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.07, green: 0.09, blue: 0.14)
        : Color(red: 0.98, green: 0.99, blue: 1.00)
    }

    static func navBarForeground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.95, green: 0.96, blue: 0.98)
        : Color(red: 0.12, green: 0.16, blue: 0.24)
    }

    static func tabBarBackground(for scheme: ColorScheme) -> Color {
      scheme == .dark
        ? Color(red: 0.07, green: 0.09, blue: 0.14)
        : Color(red: 0.98, green: 0.99, blue: 1.00)
    }

    // MARK: - Status

    static let success = Color(uiColor: .systemGreen)
    static let danger = Color(uiColor: .systemRed)
    static let warning = Color(uiColor: .systemOrange)
    static let disabled = Color(uiColor: .systemGray3)

    // MARK: - Overlays

    static let scrim = Color.black.opacity(0.5)
    static let splashRing = Color(uiColor: .systemBlue).opacity(0.25)
    static let splashCore = Color(uiColor: .systemTeal).opacity(0.8)
  }

  static func avatarGradient(for scheme: ColorScheme) -> [Color] {
    switch scheme {
    case .dark:
      return [
        Color(red: 0.22, green: 0.45, blue: 0.83),
        Color(red: 0.10, green: 0.62, blue: 0.64),
      ]
    case .light:
      return [
        Color(red: 0.15, green: 0.38, blue: 0.77),
        Color(red: 0.08, green: 0.57, blue: 0.58),
      ]
    @unknown default:
      return [
        Color(red: 0.15, green: 0.38, blue: 0.77),
        Color(red: 0.08, green: 0.57, blue: 0.58),
      ]
    }
  }

  static func heroGradient(for scheme: ColorScheme) -> [Color] {
    switch scheme {
    case .dark:
      return [
        Color(red: 0.10, green: 0.28, blue: 0.52),
        Color(red: 0.05, green: 0.16, blue: 0.28),
      ]
    case .light:
      return [
        Color(red: 0.89, green: 0.94, blue: 1.00),
        Color(red: 0.84, green: 0.92, blue: 0.98),
      ]
    @unknown default:
      return [
        Color(red: 0.89, green: 0.94, blue: 1.00),
        Color(red: 0.84, green: 0.92, blue: 0.98),
      ]
    }
  }

  static func splashGradient(for scheme: ColorScheme) -> [Color] {
    switch scheme {
    case .dark:
      return [
        Color(red: 0.05, green: 0.08, blue: 0.14),
        Color(red: 0.03, green: 0.04, blue: 0.08),
      ]
    case .light:
      return [
        Color(red: 0.95, green: 0.97, blue: 1.00),
        Color(red: 0.88, green: 0.93, blue: 0.99),
      ]
    @unknown default:
      return [
        Color(red: 0.05, green: 0.08, blue: 0.14),
        Color(red: 0.03, green: 0.04, blue: 0.08),
      ]
    }
  }
}
