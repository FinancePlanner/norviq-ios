import AnyAPI
import Foundation
import StockPlanShared

struct GetTickerSentimentEndpoint: Endpoint {
    typealias Response = TickerSentimentResponse
    let symbol: String
    let days: Int?
    let limit: Int?

    var method: HTTPMethod { .get }
    var path: String { "/v1/insights/tickers/\(symbol)/sentiment" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        var params: Parameters = [:]
        if let days { params["days"] = String(days) }
        if let limit { params["limit"] = String(limit) }
        return params
    }
}
