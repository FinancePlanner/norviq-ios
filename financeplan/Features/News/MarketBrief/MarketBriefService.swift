import Factory
import Foundation
import StockPlanShared

/// Everything the market brief card and its alert toggle need from the backend.
protocol MarketBriefServicing: Sendable {
  /// The latest brief when `slot`/`date` are nil; that exact brief otherwise.
  func brief(language: String, slot: MarketBriefSlot?, date: String?) async throws -> MarketBriefResponse
  func notificationPreferences() async throws -> MarketBriefNotificationPreferences
  func updateNotificationPreferences(enabled: Bool, language: String) async throws -> MarketBriefNotificationPreferences
}

extension MarketBriefServicing {
  func latestBrief(language: String) async throws -> MarketBriefResponse {
    try await brief(language: language, slot: nil, date: nil)
  }
}

struct DefaultMarketBriefService: MarketBriefServicing {
  private let client: MarketBriefHTTPClient

  init(environmentManager: AppEnvironmentManager, session: any HTTPClientSession = URLSession.shared) {
    self.client = MarketBriefHTTPClient(
      baseURL: environmentManager.current.apiBaseUrl,
      session: session,
      authTokenProvider: { await Container.shared.authSessionStore().authToken }
    )
  }

  func brief(language: String, slot: MarketBriefSlot?, date: String?) async throws -> MarketBriefResponse {
    try await client.brief(lang: language, slot: slot, date: date)
  }

  func notificationPreferences() async throws -> MarketBriefNotificationPreferences {
    try await client.notificationPreferences()
  }

  func updateNotificationPreferences(enabled: Bool, language: String) async throws -> MarketBriefNotificationPreferences {
    try await client.updateNotificationPreferences(enabled: enabled, language: language)
  }
}
