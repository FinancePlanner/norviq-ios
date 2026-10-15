import Foundation
import StockPlanShared

/// Where a market brief push or link points.
///
/// The backend sends category `MARKET_BRIEF`, thread `market-brief` and a
/// payload of `schemaVersion` (1), `type` (`market_brief`), `slot`,
/// `tradingDate` and `deepLink`
/// (`financeplan://market/brief?slot=morning&date=2026-10-15`). A link without
/// a usable slot and date still opens the card, on the latest brief.
nonisolated struct MarketBriefDeepLink: Equatable, Sendable {
  static let category = "MARKET_BRIEF"
  static let threadIdentifier = "market-brief"
  static let payloadType = "market_brief"
  static let host = "market"
  static let path = "brief"

  /// Nil opens the latest brief.
  let ref: MarketBriefRef?

  init(ref: MarketBriefRef?) {
    self.ref = ref
  }

  init(slot: String?, date: String?) {
    self.ref = Self.ref(slot: slot, date: date)
  }

  /// Parses `financeplan://market/brief[?slot=…&date=…]`. Nil for any other URL.
  static func parse(_ url: URL) -> MarketBriefDeepLink? {
    guard let scheme = url.scheme?.lowercased(), AssistantDeepLink.schemes.contains(scheme),
          url.host?.lowercased() == host
    else { return nil }
    let parts = url.pathComponents.filter { $0 != "/" }
    guard parts.first?.lowercased() == path else { return nil }
    let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    func value(_ name: String) -> String? { query.first { $0.name == name }?.value }
    return MarketBriefDeepLink(slot: value("slot"), date: value("date"))
  }

  static func parse(_ string: String?) -> MarketBriefDeepLink? {
    guard let string, let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      return nil
    }
    return parse(url)
  }

  /// Both halves or nothing: the server treats a lone slot or date as "latest".
  static func ref(slot: String?, date: String?) -> MarketBriefRef? {
    guard let rawSlot = slot?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
          let slot = MarketBriefSlot(rawValue: rawSlot),
          let date = date?.trimmingCharacters(in: .whitespacesAndNewlines),
          isTradingDate(date)
    else { return nil }
    return MarketBriefRef(slot: slot, tradingDate: date)
  }

  /// `yyyy-MM-dd`, digits only. Kept strict because the value goes into a query.
  static func isTradingDate(_ value: String) -> Bool {
    let parts = value.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2 else { return false }
    return parts.allSatisfy { $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }
  }
}

extension Notification.Name {
  /// Posted by `ContentView` when a routed push or link should open the
  /// market brief. `userInfo["slot"]` and `userInfo["tradingDate"]` are optional.
  static let openMarketBriefFromPushNotification = Notification.Name("openMarketBriefFromPushNotification")
}
