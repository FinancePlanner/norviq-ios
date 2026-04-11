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
    userProfileUpdateParameters(request)
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
    ["username": request.username]
  }
}

struct UpdateEmailEndpoint: Endpoint {
  typealias Response = UpdateUserProfileResponse

  let request: UpdateEmailRequest

  var method: HTTPMethod { .patch }
  var path: String { "/v1/users/email" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["email": request.email]
  }
}

struct UpdatePasswordEndpoint: Endpoint {
  typealias Response = APIMessageResponse

  let request: UpdatePasswordRequest

  var method: HTTPMethod { .patch }
  var path: String { "/v1/users/password" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    [
      "currentPassword": request.currentPassword,
      "newPassword": request.newPassword
    ]
  }
}

private func userProfileUpdateParameters(_ request: UpdateUserProfileRequest) -> Parameters {
  var userProfile: Parameters = [
    "id": request.userProfile.id,
    "email": request.userProfile.email
  ]
  if let bio = request.userProfile.bio {
    userProfile["bio"] = bio
  }
  if let avatarURL = request.userProfile.avatarURL {
    userProfile["avatar_url"] = avatarURL.absoluteString
  }
  if let bannerAvatarURL = request.userProfile.bannerAvatarURL {
    userProfile["banner_avatar_url"] = bannerAvatarURL.absoluteString
  }
  if let username = request.userProfile.username {
    userProfile["username"] = username
  }
  return ["user_profile": userProfile]
}
