import AnyAPI
import Foundation
import StockPlanShared

struct GetActivitiesEndpoint: Endpoint {
    typealias Response = [UserActivityResponse]
    
    let limit: Int?
    
    var method: HTTPMethod { .get }
    var path: String { "/v1/activities" }
    var decoder: JSONDecoder { .stockPlanShared }
    
    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        if let limit { params["limit"] = limit }
        return params
    }
}
