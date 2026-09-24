import AnyAPI
import Foundation
import StockPlanShared

nonisolated struct GetOnboardingStateEndpoint: Endpoint {
  typealias Response = OnboardingStateDTO

  var method: HTTPMethod { .get }
  var path: String { "/v1/onboarding" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct PatchOnboardingStateEndpoint: Endpoint {
  typealias Response = OnboardingStateDTO

  let request: OnboardingPatchRequest

  var method: HTTPMethod { .patch }
  var path: String { "/v1/onboarding" }
  var decoder: JSONDecoder { .stockPlanShared }

  /// Only the fields that are set: the server rejects anything else.
  func asParameters() throws -> Parameters {
    var parameters: Parameters = [:]
    if let step = request.funnelStep { parameters["funnelStep"] = step }
    if let completed = request.funnelCompleted { parameters["funnelCompleted"] = completed }
    if let dismissed = request.guidedStartDismissed { parameters["guidedStartDismissed"] = dismissed }
    return parameters
  }
}
