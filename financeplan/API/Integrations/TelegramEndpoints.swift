import AnyAPI
import Foundation
import StockPlanShared

nonisolated struct TelegramStatusEndpoint: Endpoint {
  typealias Response = TelegramStatus

  var method: HTTPMethod { .get }
  var path: String { "/v1/integrations/telegram" }
  var decoder: JSONDecoder { .stockPlanShared }
}

nonisolated struct TelegramCreateCodeEndpoint: Endpoint {
  typealias Response = TelegramPairingCode

  var method: HTTPMethod { .post }
  var path: String { "/v1/integrations/telegram/code" }
  var decoder: JSONDecoder { .stockPlanShared }
}

nonisolated struct TelegramDisconnectEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse

  var method: HTTPMethod { .delete }
  var path: String { "/v1/integrations/telegram" }
  var decoder: JSONDecoder { .stockPlanShared }
}

nonisolated struct TelegramPreferencesEndpoint: Endpoint {
  typealias Response = TelegramPreferencesResponse

  var method: HTTPMethod { .get }
  var path: String { "/v1/integrations/telegram/preferences" }
  var decoder: JSONDecoder { .stockPlanShared }
}

nonisolated struct TelegramUpdatePreferenceEndpoint: Endpoint {
  typealias Response = TelegramPreferencesResponse

  let update: TelegramPreferenceUpdate

  var method: HTTPMethod { .put }
  var path: String { "/v1/integrations/telegram/preferences" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var parameters: Parameters = [
      "kind": update.kind,
      "enabled": update.enabled
    ]
    if let start = update.quietHoursStart { parameters["quietHoursStart"] = start }
    if let end = update.quietHoursEnd { parameters["quietHoursEnd"] = end }
    if let timezone = update.timezone { parameters["timezone"] = timezone }
    return parameters
  }
}
