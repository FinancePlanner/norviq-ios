import AnyAPI
import Foundation
import StockPlanShared

// Use shared OAuth DTOs
typealias OAuthProviderKind = OAuthProvider
typealias OAuthStartRequestPayload = OAuthStartRequest
typealias OAuthStartResponsePayload = OAuthStartResponse
typealias OAuthExchangeRequestPayload = OAuthExchangeRequest

typealias AuthMFAChannelPayload = AuthMFAChannel
typealias AuthMFAChallengeResponsePayload = AuthMFAChallengeResponse
typealias AuthMFAVerifyRequestPayload = AuthMFAVerifyRequest
typealias AuthMFAResendRequestPayload = AuthMFAResendRequest
typealias AuthLoginOutcomeStatusPayload = AuthLoginOutcomeStatus
typealias AuthLoginOutcomePayload = AuthLoginOutcome

nonisolated struct LoginEndpoint: Endpoint {
  typealias Response = AuthLoginOutcomePayload

  let email: String
  let password: String

  var method: HTTPMethod { .post }
  var path: String { "/v1/auth/login" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    params["email"] = email
    params["password"] = password
    return params
  }
}

nonisolated struct SignupEndpoint: Endpoint {
  typealias Response = AuthResponse

  let username: String
  let email: String
  let password: String
  let confirmPassword: String
  let dateOfBirth: Date

  var method: HTTPMethod { .post }
  var path: String { "/v1/auth/register" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    params["username"] = username
    params["email"] = email
    params["password"] = password
    params["confirmPassword"] = confirmPassword
    params["dateOfBirth"] = Self.formatter.string(from: dateOfBirth)
    return params
  }

  private static var formatter: ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = .init(secondsFromGMT: 0)
    return formatter
  }
}

nonisolated struct ForgotPasswordEndpoint: Endpoint {
  typealias Response = AuthForgotPasswordResponse

  let email: String

  var method: HTTPMethod { .post }
  var path: String { "/v1/auth/forgot-password" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    params["email"] = email
    return params
  }
}

nonisolated struct LogoutEndpoint: Endpoint {
  typealias Response = EmptyAPIResponse

  let refreshToken: String
  let endpointPath: String

  var method: HTTPMethod { .post }
  var path: String { endpointPath }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    params["refreshToken"] = refreshToken
    return params
  }
}

nonisolated struct RefreshEndpoint: Endpoint {
  typealias Response = AuthResponse

  let refreshToken: String

  var method: HTTPMethod { .post }
  var path: String { "/v1/auth/refresh" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var params: Parameters = [:]
    params["refreshToken"] = refreshToken
    return params
  }
}

nonisolated struct OAuthStartEndpoint: Endpoint {
  typealias Response = OAuthStartResponsePayload

  let provider: OAuthProviderKind
  let redirectURI: String

  var method: HTTPMethod { .post }
  var path: String { "/v1/auth/oauth/\(provider.rawValue)/start" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["redirectURI": redirectURI]
  }
}

nonisolated struct OAuthExchangeEndpoint: Endpoint {
  typealias Response = AuthLoginOutcomePayload

  let provider: OAuthProviderKind
  let payload: OAuthExchangeRequestPayload

  var method: HTTPMethod { .post }
  var path: String { "/v1/auth/oauth/\(provider.rawValue)/exchange" }
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

nonisolated struct MFAVerifyEndpoint: Endpoint {
  typealias Response = AuthResponse

  let payload: AuthMFAVerifyRequestPayload

  var method: HTTPMethod { .post }
  var path: String { "/v1/auth/mfa/verify" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    [
      "challengeId": payload.challengeId.uuidString,
      "code": payload.code
    ]
  }
}

nonisolated struct MFAResendEndpoint: Endpoint {
  typealias Response = AuthMFAChallengeResponsePayload

  let payload: AuthMFAResendRequestPayload

  var method: HTTPMethod { .post }
  var path: String { "/v1/auth/mfa/resend" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    [
      "challengeId": payload.challengeId.uuidString
    ]
  }
}
