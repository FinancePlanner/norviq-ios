import AnyAPI
import Foundation
import StockPlanShared

nonisolated struct GetDashboardEndpoint: Endpoint {
    typealias Response = DashboardResponse
    var method: HTTPMethod { .get }
    var path: String { "/v1/dashboard" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetDashboardInsightsEndpoint: Endpoint {
    typealias Response = DashboardInsightsResponse
    var method: HTTPMethod { .get }
    var path: String { "/v1/dashboard/insights" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

nonisolated struct GetWhyMovedEndpoint: Endpoint {
    typealias Response = WhyMovedResponse
    var method: HTTPMethod { .get }
    var path: String { "/v1/dashboard/why-moved" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}
