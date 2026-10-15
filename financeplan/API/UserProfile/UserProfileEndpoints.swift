//
//  UserProfileEndpoints.swift
//  financeplan
//
//  Created by Fernando Correia on 07.03.26.
//

import AnyAPI
import Foundation
import StockPlanShared

nonisolated struct GetUserProfileEndpoint: Endpoint {
  typealias Response = GetUserProfileResponse

  var method: HTTPMethod { .get }
  var path: String { "/v1/users" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct UpdateUserProfileEndpoint: Endpoint {
  typealias Response = UpdateUserProfileResponse

  let request: UpdateUserProfileRequest

  var method: HTTPMethod { .put }
  var path: String { "/v1/users" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    userProfileUpdateParameters(request)
  }
}

nonisolated struct DeleteUserProfileEndpoint: Endpoint {
  typealias Response = DeleteUserProfileResponse

  var method: HTTPMethod { .delete }
  var path: String { "/v1/users" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters { [:] }
}

nonisolated struct UpdateUsernameEndpoint: Endpoint {
  typealias Response = UpdateUserProfileResponse

  let request: UpdateUsernameRequest

  var method: HTTPMethod { .patch }
  var path: String { "/v1/users/username" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    ["username": request.username]
  }
}

/// `PATCH /v1/users/email` body. Local rather than StockPlanShared's
/// `UpdateEmailRequest` (pinned by exact version, no password field): the
/// backend now requires the current password to move the account.
nonisolated struct ChangeEmailRequest: Sendable, Equatable {
  let email: String
  let currentPassword: String
  /// This device's refresh token. The backend revokes every other session on
  /// success and spares this one, so the app stays signed in.
  let refreshToken: String?
}

nonisolated struct UpdateEmailEndpoint: Endpoint {
  typealias Response = UpdateUserProfileResponse

  let request: ChangeEmailRequest

  var method: HTTPMethod { .patch }
  var path: String { "/v1/users/email" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var parameters: Parameters = [
      "email": request.email,
      "currentPassword": request.currentPassword,
    ]
    if let refreshToken = request.refreshToken, !refreshToken.isEmpty {
      parameters["refreshToken"] = refreshToken
    }
    return parameters
  }

  func encode(to _: Encoder) throws {}
}

nonisolated struct UpdatePasswordEndpoint: Endpoint {
  typealias Response = APIMessageResponse

  let request: UpdatePasswordRequest
  /// This device's refresh token. The backend revokes every other session on
  /// success and spares this one, so the app stays signed in.
  var refreshToken: String?

  var method: HTTPMethod { .patch }
  var path: String { "/v1/users/password" }
  var decoder: JSONDecoder { .stockPlanShared }

  func asParameters() throws -> Parameters {
    var parameters: Parameters = [
      "currentPassword": request.currentPassword,
      "newPassword": request.newPassword
    ]
    if let refreshToken, !refreshToken.isEmpty {
      parameters["refreshToken"] = refreshToken
    }
    return parameters
  }
}

nonisolated private func userProfileUpdateParameters(_ request: UpdateUserProfileRequest) -> Parameters {
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
