import Foundation

/// Where a market brief was shared to. The raw value is both the permalink's
/// `utm_source` and the `channel` property on `market_brief_shared`.
nonisolated enum MarketBriefShareChannel: String, CaseIterable, Sendable {
  /// The system share sheet with the permalink.
  case link
  /// The system share sheet with the rendered card image.
  case image
  case x
  case reddit
  case whatsapp
  case discord
  case copyLink = "copy_link"
}
