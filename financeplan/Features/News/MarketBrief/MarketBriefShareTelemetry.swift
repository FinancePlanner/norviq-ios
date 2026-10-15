import Foundation
import PostHog
import StockPlanShared

/// `market_brief_shared`, sent once per share action from the brief card.
struct MarketBriefShareTelemetry {
  static let event = "market_brief_shared"

  private let capture: (String, [String: Any]) -> Void

  init(capture: @escaping (String, [String: Any]) -> Void = { event, properties in
    PostHogSDK.shared.capture(event, properties: properties)
  }) {
    self.capture = capture
  }

  func shared(_ payload: MarketBriefSharePayload, channel: MarketBriefShareChannel) {
    capture(Self.event, Self.properties(payload, channel: channel))
  }

  nonisolated static func properties(
    _ payload: MarketBriefSharePayload,
    channel: MarketBriefShareChannel
  ) -> [String: String] {
    [
      "channel": channel.rawValue,
      "slot": payload.slot.rawValue,
      "date": payload.tradingDate,
      "lang": payload.languageCode,
      "surface": "card"
    ]
  }
}
