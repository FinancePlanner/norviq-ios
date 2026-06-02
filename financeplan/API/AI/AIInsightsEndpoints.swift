import AnyAPI
import Foundation
import StockPlanShared

/// Generate one educational AI insight card for the authenticated user.
/// The kind selects the server-side prompt (expenses / portfolio / summary).
struct GenerateAIInsightEndpoint: Endpoint {
    typealias Response = AIInsightCardResponse
    let kind: AIInsightKind

    var method: HTTPMethod { .get }
    var path: String { "/v1/ai/insights/\(kind.rawValue)" }
    var decoder: JSONDecoder { .stockPlanShared }
    func asParameters() throws -> Parameters { [:] }
}
