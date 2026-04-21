import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
  case english = "en"
  case portuguesePortugal = "pt-PT"

  static let storageKey = "app_language"

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
    AppLanguage(rawValue: rawValue) ?? .english
  }

  static var stored: AppLanguage {
    from(UserDefaults.standard.string(forKey: storageKey) ?? AppLanguage.english.rawValue)
  }

  static func apply(_ language: AppLanguage, defaults: UserDefaults = .standard) {
    defaults.set(language.rawValue, forKey: storageKey)
    applyBundleLanguage(language, defaults: defaults)
  }

  static func applyStoredLanguage(defaults: UserDefaults = .standard) {
    applyBundleLanguage(from(defaults.string(forKey: storageKey) ?? AppLanguage.english.rawValue), defaults: defaults)
  }

  static func applyBundleLanguage(_ language: AppLanguage, defaults: UserDefaults = .standard) {
    defaults.set(language.appleLanguages, forKey: "AppleLanguages")
    defaults.synchronize()
  }
}
