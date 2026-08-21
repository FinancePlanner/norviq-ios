import Foundation
import StockPlanShared

// Declared app-locally rather than in StockPlanShared.
//
// iOS pins StockPlanShared at an exact version and the backend pins a different
// one, so promoting a type there means a new tag plus two coordinated bumps.
// AccountLinkingDTOs.swift already shadows shared types for the same reason.
// These can move to the shared package once the pins converge.

nonisolated struct TelegramStatus: Codable, Sendable, Equatable {
  /// False when the deployment has no bot configured. The whole row is hidden
  /// rather than offering a Connect button that could only fail.
  let available: Bool
  let connected: Bool
  let botUsername: String
  let lastSeenAt: Date?
  let connectedAt: Date?
}

nonisolated struct TelegramPairingCode: Codable, Sendable, Equatable {
  /// Readable exactly once — the server keeps only a hash.
  let code: String
  let expiresAt: Date
  /// Ready-made `https://t.me/...` link.
  let deepLink: String
}

nonisolated struct TelegramAlertPreference: Codable, Sendable, Equatable, Identifiable {
  let kind: String
  let enabled: Bool
  let quietHoursStart: Int?
  let quietHoursEnd: Int?
  let timezone: String

  var id: String { kind }
}

nonisolated struct TelegramPreferencesResponse: Codable, Sendable, Equatable {
  let preferences: [TelegramAlertPreference]
}

nonisolated struct TelegramPreferenceUpdate: Codable, Sendable, Equatable {
  let kind: String
  let enabled: Bool
  let quietHoursStart: Int?
  let quietHoursEnd: Int?
  let timezone: String?
}

nonisolated extension TelegramAlertPreference {
  /// Renders an alert kind for a person. An unknown kind passes through rather
  /// than rendering blank, so a backend that adds one degrades visibly.
  var label: String {
    switch kind {
    case "price_target": "Price targets"
    case "budget": "Budget alerts"
    case "earnings": "Earnings reminders"
    case "tax": "Tax opportunities"
    case "watchlist_screen": "Watchlist screens"
    case "rebalancing": "Rebalancing drift"
    case "financial_goal": "Financial goals"
    case "thesis_watch": "Thesis watch"
    default: kind
    }
  }
}
