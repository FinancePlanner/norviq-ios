import AnyAPI
import Foundation
import StockPlanShared

struct GetGoalsEndpoint: Endpoint {
    typealias Response = [GoalResponse]
    var method: HTTPMethod { .get }
    var path: String { "/v1/goals" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}

struct CreateGoalEndpoint: Endpoint {
    typealias Response = GoalResponse
    let payload: GoalRequest
    var method: HTTPMethod { .post }
    var path: String { "/v1/goals" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        let data = try JSONEncoder.stockPlanShared.encode(payload)
        return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
    }
}

struct UpdateGoalEndpoint: Endpoint {
    typealias Response = GoalResponse
    let id: String
    let payload: GoalRequest
    var method: HTTPMethod { .patch }
    var path: String { "/v1/goals/\(id)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        let data = try JSONEncoder.stockPlanShared.encode(payload)
        return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
    }
}

struct UpdateGoalStatusEndpoint: Endpoint {
    typealias Response = GoalResponse
    let id: String
    let payload: GoalStatusUpdateRequest
    var method: HTTPMethod { .patch }
    var path: String { "/v1/goals/\(id)/status" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters {
        let data = try JSONEncoder.stockPlanShared.encode(payload)
        return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
    }
}

struct DeleteGoalEndpoint: Endpoint {
    typealias Response = EmptyAPIResponse
    let id: String
    var method: HTTPMethod { .delete }
    var path: String { "/v1/goals/\(id)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}
