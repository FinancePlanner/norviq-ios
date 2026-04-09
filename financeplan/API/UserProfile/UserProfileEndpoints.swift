//
//  UserProfileEndpoints.swift
//  financeplan
//
//  Created by Fernando Correia on 07.03.26.
//

import AnyAPI
import Foundation
import StockPlanShared

struct GetUserProfileEndpoint: Endpoint {
  typealias Response = GetUserProfileResponse

  var method: HTTPMethod { .get }
  var path: String { "/v1/users" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct UpdateUserProfileEndpoint: Endpoint {
  typealias Response = UpdateUserProfileResponse

  let request: UpdateUserProfileRequest

  var method: HTTPMethod { .put }
  var path: String { "/v1/users" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    let data = try JSONEncoder.stockPlanShared.encode(request)
    return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
  }
}

struct DeleteUserProfileEndpoint: Endpoint {
  typealias Response = DeleteUserProfileResponse

  var method: HTTPMethod { .delete }
  var path: String { "/v1/users" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

struct UpdateUsernameEndpoint: Endpoint {
  typealias Response = UpdateUserProfileResponse

  let request: UpdateUsernameRequest

  var method: HTTPMethod { .patch }
  var path: String { "/v1/users/username" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    let data = try JSONEncoder.stockPlanShared.encode(request)
    return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
  }
}

struct UpdateEmailEndpoint: Endpoint {
  typealias Response = UpdateUserProfileResponse

  let request: UpdateEmailRequest

  var method: HTTPMethod { .patch }
  var path: String { "/v1/users/email" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    let data = try JSONEncoder.stockPlanShared.encode(request)
    return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
  }
}

struct UpdatePasswordEndpoint: Endpoint {
  typealias Response = APIMessageResponse

  let request: UpdatePasswordRequest

  var method: HTTPMethod { .patch }
  var path: String { "/v1/users/password" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    let data = try JSONEncoder.stockPlanShared.encode(request)
    return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
  }
}
