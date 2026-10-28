import AnyAPI
import Foundation

/// Sends the in-app language so the server localizes what it writes
/// (achievement titles and descriptions). The app's language is its own
/// setting, not the device's, so URLSession's default header won't do.
nonisolated enum AcceptLanguageHeader {
  static let name = "Accept-Language"

  static func provider(
    _ language: @escaping @Sendable () -> AppLanguage
  ) -> @Sendable (any Endpoint) -> [(name: String, value: String)] {
    { _ in [(name: name, value: language().rawValue)] }
  }
}
