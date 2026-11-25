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

// MARK: - Export Studio

/// `GET /v1/market/brief/exports`: which renders exist for an edition, and the
/// `rev`/`v` query that busts the cache for each.
nonisolated struct GetMarketBriefExportsEndpoint: Endpoint {
  typealias Response = MarketBriefExportManifest
  let lang: String
  let slot: MarketBriefSlot
  /// Lisbon calendar date, `yyyy-MM-dd`.
  let date: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/brief/exports" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["lang": lang, "slot": slot.rawValue, "date": date]
  }
}

/// `GET /v1/market/brief/export`: one rendered file (PNG or PDF) as raw bytes.
nonisolated struct GetMarketBriefExportFileEndpoint: Endpoint {
  typealias Response = Data
  /// The backend's fill timeout is 20 s, so a cold render needs more than the
  /// URLSession default would always give a busy renderer.
  static let timeout: TimeInterval = 30

  let lang: String
  let slot: MarketBriefSlot
  let date: String
  let format: MarketBriefExportFormat
  /// The manifest's `query` for this format, e.g. `rev=2&v=1`.
  let query: String

  var method: HTTPMethod { .get }
  var path: String { "/v1/market/brief/export" }

  /// `rev` and `v` come only from the manifest, and only in the exact shape
  /// the backend wrote; anything else is dropped rather than forwarded.
  static func revisionParameters(from query: String) -> [String: String] {
    guard query.range(of: #"^rev=\d+&v=\d+$"#, options: .regularExpression) != nil else { return [:] }
    var result: [String: String] = [:]
    for pair in query.split(separator: "&") {
      let parts = pair.split(separator: "=", maxSplits: 1)
      if parts.count == 2 { result[String(parts[0])] = String(parts[1]) }
    }
    return result
  }

  func asParameters() throws -> Parameters {
    var parameters: Parameters = ["lang": lang, "slot": slot.rawValue, "date": date, "format": format.rawValue]
    for (key, value) in Self.revisionParameters(from: query) { parameters[key] = value }
    return parameters
  }
}
