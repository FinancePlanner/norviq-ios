import AnyAPI
import Foundation
import StockPlanShared

struct SubmitFeedbackEndpoint: Endpoint {
  typealias Response = FeedbackResponse
  let payload: FeedbackRequest
    var method: HTTPMethod { .post }
    var path: String { "/v1/feedback" }
    var decoder: JSONDecoder { .stockPlanShared }

    func asParameters() throws -> Parameters {
      let data = try JSONEncoder.stockPlanShared.encode(payload)
      return try JSONSerialization.jsonObject(with: data) as? Parameters ?? [:]
    }
  }
