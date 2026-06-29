import AnyAPI
import Foundation
import StockPlanShared

struct OAuthLinkedAccountsEndpoint: Endpoint {
  typealias Response = OAuthLinkedAccountsResponse

  var method: HTTPMethod { .get }
  var path: String { "/v1/auth/oauth/identities" }
  var decoder: JSONDecoder { .stockPlanShared }
}

struct OAuthLinkStartEndpoint: Endpoint {
  typealias Response = OAuthStartResponsePayload

  let provider: OAuthProviderKind
  let redirectURI: String

  var method: HTTPMethod { .post }
  var path: String { "/v1/auth/oauth/\(provider.rawValue)/link/start" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["redirectURI": redirectURI]
  }
}

struct OAuthLinkExchangeEndpoint: Endpoint {
  typealias Response = OAuthLinkResponse

  let provider: OAuthProviderKind
  let payload: OAuthExchangeRequestPayload

  var method: HTTPMethod { .post }
  var path: String { "/v1/auth/oauth/\(provider.rawValue)/link/exchange" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    [
      "flowId": payload.flowId.uuidString,
      "code": payload.code,
      "state": payload.state,
      "redirectURI": payload.redirectURI
    ]
  }
}
