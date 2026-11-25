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

  func shared(
    _ payload: MarketBriefSharePayload,
    channel: MarketBriefShareChannel,
    method: String? = nil,
    surface: String = "card"
  ) {
    capture(Self.event, Self.properties(payload, channel: channel, method: method, surface: surface))
  }

  nonisolated static func properties(
    _ payload: MarketBriefSharePayload,
    channel: MarketBriefShareChannel,
    method: String? = nil,
    surface: String = "card"
  ) -> [String: String] {
    var properties = [
      "channel": channel.rawValue,
      "slot": payload.slot.rawValue,
      "date": payload.tradingDate,
      "lang": payload.languageCode,
      "surface": surface
    ]
    if let method {
      properties["method"] = method
    }
    return properties
  }
}
