import AnyAPI
import Foundation
import StockPlanShared

// Shared AI market briefs: a pre-market brief at 08:15 Lisbon and a
// market-close recap at 22:30, in `en` and `pt-PT`. The same for every user;
// only the language varies. Spec: norviq-backend
// docs/superpowers/specs/2026-10-08-market-brief-design.md.

/// `GET /v1/market/brief`. Without `slot` and `date` it returns the latest
/// brief; with both, that exact brief (404 when it does not exist).
nonisolated struct GetMarketBriefEndpoint: Endpoint {
  typealias Response = MarketBriefResponse
  /// `en` or `pt-PT` (`AppLanguage.rawValue`).
  let lang: String
  let slot: MarketBriefSlot?
  /// Lisbon calendar date, `yyyy-MM-dd`.
  let date: String?

  init(lang: String, slot: MarketBriefSlot? = nil, date: String? = nil) {
    self.lang = lang
    self.slot = slot
    self.date = date
  }

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/brief" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var parameters: Parameters = ["lang": lang]
    // The server only honours the pair; half of it would silently mean "latest".
    if let slot, let date, !date.isEmpty {
      parameters["slot"] = slot.rawValue
      parameters["date"] = date
    }
    return parameters
  }
}

nonisolated struct GetMarketBriefNotificationsEndpoint: Endpoint {
  typealias Response = MarketBriefNotificationPreferences
  var method: HTTPMethod { .get }
  var path: String { "/v1/market/brief/notifications" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct UpdateMarketBriefNotificationsEndpoint: Endpoint {
  typealias Response = MarketBriefNotificationPreferences
  let enabled: Bool
  /// The language the pushes are written in: `en` or `pt-PT`.
  let language: String

  var method: HTTPMethod { .put }
  var path: String { "/v1/market/brief/notifications" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { ["enabled": enabled, "language": language] }
}
