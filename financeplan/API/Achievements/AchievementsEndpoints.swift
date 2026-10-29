import AnyAPI
import Foundation
import StockPlanShared

nonisolated struct GetAchievementsEndpoint: Endpoint {
  typealias Response = AchievementsResponse
  var method: HTTPMethod { .get }
  var path: String { "/v1/achievements" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetUnseenAchievementsEndpoint: Endpoint {
  typealias Response = [AchievementUnlock]
  var method: HTTPMethod { .get }
  var path: String { "/v1/achievements/unseen" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct MarkAchievementsSeenEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse
  let payload: AchievementSeenRequest
  var method: HTTPMethod { .post }
  var path: String { "/v1/achievements/seen" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { ["ids": payload.ids] }
}

nonisolated struct SetAchievementShowcaseEndpoint: Endpoint {
  typealias Response = AchievementsResponse
  let payload: AchievementShowcaseRequest
  var method: HTTPMethod { .put }
  var path: String { "/v1/achievements/showcase" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters {
    ["items": payload.items.map { ["key": $0.key, "tier": $0.tier] }]
  }
}
