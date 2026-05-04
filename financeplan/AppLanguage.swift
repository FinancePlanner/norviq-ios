import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
  case english = "en"
  case portuguesePortugal = "pt-PT"

  static let storageKey = "app_language"
  static let defaultLanguage = AppLanguage.english

  var id: String { rawValue }

  var localeIdentifier: String { rawValue }

  var appleLanguages: [String] {
    switch self {
    case .english:
      ["en"]
    case .portuguesePortugal:
      ["pt-PT", "pt"]
    }
  }

  var displayName: String {
    switch self {
    case .english:
      "English"
    case .portuguesePortugal:
      "Português"
    }
  }

  static func from(_ rawValue: String) -> AppLanguage {
    AppLanguage(rawValue: rawValue) ?? defaultLanguage
  }

  static var stored: AppLanguage {
    from(UserDefaults.standard.string(forKey: storageKey) ?? defaultLanguage.rawValue)
  }

  static func apply(_ language: AppLanguage, defaults: UserDefaults = .standard) {
    defaults.set(language.rawValue, forKey: storageKey)
    applyBundleLanguage(language, defaults: defaults)
  }

  static func applyStoredLanguage(defaults: UserDefaults = .standard) {
    guard let rawValue = defaults.string(forKey: storageKey) else {
      apply(defaultLanguage, defaults: defaults)
      return
    }
    applyBundleLanguage(from(rawValue), defaults: defaults)
  }

  static func applyBundleLanguage(_ language: AppLanguage, defaults: UserDefaults = .standard) {
    defaults.set(language.appleLanguages, forKey: "AppleLanguages")
    defaults.synchronize()
  }
}
