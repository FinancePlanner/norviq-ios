import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
  case english = "en"
  case portuguesePortugal = "pt-PT"

  static let storageKey = "app_language"

  var id: String { rawValue }

  var localeIdentifier: String { rawValue }

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
}
