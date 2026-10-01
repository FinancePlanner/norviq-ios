import AnyAPI
import Foundation
import StockPlanShared

nonisolated struct GetXPSummaryEndpoint: Endpoint {
  typealias Response = XPSummary
  var method: HTTPMethod { .get }
  var path: String { "/v1/gamification/xp" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetXPEventsEndpoint: Endpoint {
  typealias Response = XPHistoryResponse
  let cursor: String?
  var method: HTTPMethod { .get }
  var path: String { "/v1/gamification/xp/events" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters {
    guard let cursor else { return [:] }
    return ["cursor": cursor]
  }
}

nonisolated struct GetStreaksEndpoint: Endpoint {
  typealias Response = StreakSummary
  var method: HTTPMethod { .get }
  var path: String { "/v1/gamification/streaks" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

/// The local day comes from the `X-Timezone` header, which
/// `GamificationHTTPClient` adds to every call.
nonisolated struct CheckInEndpoint: Endpoint {
  typealias Response = CheckInResponse
  var method: HTTPMethod { .post }
  var path: String { "/v1/gamification/check-in" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct ReportBudgetStreakEndpoint: Endpoint {
  typealias Response = StreakSummary
  let payload: BudgetStreakReport
  var method: HTTPMethod { .post }
  var path: String { "/v1/gamification/streaks/budget" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { ["months": payload.months] }
}

nonisolated struct GetLeaderboardEndpoint: Endpoint {
  typealias Response = LeaderboardResponse
  let metric: LeaderboardMetric
  let period: LeaderboardPeriod
  var method: HTTPMethod { .get }
  var path: String { "/v1/social/leaderboards" }
  var decoder: JSONDecoder { .stockPlanShared }
  func asParameters() throws -> Parameters { ["metric": metric.rawValue, "period": period.rawValue] }
}
