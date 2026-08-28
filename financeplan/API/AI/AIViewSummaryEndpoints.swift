import AnyAPI
import Foundation
import StockPlanShared

/// Generate an AI summary of one screen.
///
/// `refresh` bypasses the server's hour-long cache. Sent only when true so the
/// common request stays a bare GET, which the server can serve from cache
/// without spending the user's daily allowance.
nonisolated struct GenerateAIViewSummaryEndpoint: Endpoint {
    typealias Response = AIViewSummaryResponse
    let scope: AIViewScope
    let refresh: Bool

    var method: HTTPMethod { .get }
    var path: String { "/v1/ai/view-summary/\(scope.rawValue)" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
        refresh ? ["refresh": true] : [:]
    }
}
