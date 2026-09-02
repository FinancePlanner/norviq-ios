import AnyAPI
import Foundation
import StockPlanShared

nonisolated struct GetBadgesEndpoint: Endpoint {
    typealias Response = BadgesListResponse
    var method: HTTPMethod { .get }
    var path: String { "/v1/badges" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}
