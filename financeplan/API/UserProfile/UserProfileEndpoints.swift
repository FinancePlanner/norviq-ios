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
    let data = try JSONEncoder.default.encode(request)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    var params: Parameters = [:]
    for (k, v) in json { params[k] = v }
    return params
  }
}

struct DeleteUserProfileEndpoint: Endpoint {
  typealias Response = DeleteUserProfileResponse

  var method: HTTPMethod { .delete }
  var path: String { "/v1/users" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}
