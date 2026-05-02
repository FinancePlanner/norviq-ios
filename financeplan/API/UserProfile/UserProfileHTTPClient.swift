import AnyAPI
import Foundation
import OSLog
import StockPlanShared

// MARK: - Client

struct UserProfileHTTPClient: Sendable {
  enum Error: HTTPClientError {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)

    nonisolated var errorDescription: String? {
      switch self {
      case .invalidResponse:
        return "Invalid server response."
      case let .invalidStatus(code):
        return "Request failed (\(code))."
      case let .unauthorized(message):
        return message ?? "Your session expired. Please sign in again."
      case let .api(message):
        return message
      }
    }

    var isUnauthorized: Bool {
      if case .unauthorized = self {
        return true
      }
      return false
    }

    nonisolated var statusCode: Int? {
        if case let .invalidStatus(code) = self { return code }
        return nil
    }

    nonisolated static func == (lhs: Error, rhs: Error) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse): return true
        case let (.invalidStatus(l), .invalidStatus(r)): return l == r
        case let (.unauthorized(l), .unauthorized(r)): return l == r
        case let (.api(l), .api(r)): return l == r
        default: return false
        }
    }

    static func makeInvalidResponse() -> Error { .invalidResponse }
    static func makeInvalidStatus(_ code: Int) -> Error { .invalidStatus(code) }
    static func makeUnauthorized(_ message: String?) -> Error { .unauthorized(message) }
    static func makeAPI(_ message: String) -> Error { .api(message) }
  }

  private let client: BaseHTTPClient

  init(
    baseURL: URL,
    session: any HTTPClientSession = URLSession.shared,
    authTokenProvider: @escaping @Sendable () -> String? = { nil }
  ) {
    self.client = BaseHTTPClient(
        baseURL: baseURL,
        session: session,
        authTokenProvider: authTokenProvider,
        logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "UserProfileHTTPClient"),
        decoder: .stockPlanShared
    )
  }

  func fetchProfile(_ request: GetUserProfileRequest) async throws -> GetUserProfileResponse {
    _ = request
    return try await client.call(GetUserProfileEndpoint(), errorType: Error.self)
  }

  func updateProfile(_ request: UpdateUserProfileRequest) async throws -> UpdateUserProfileResponse {
    return try await client.call(UpdateUserProfileEndpoint(request: request), errorType: Error.self)
  }

  func updateUsername(_ request: UpdateUsernameRequest) async throws -> UpdateUserProfileResponse {
    return try await client.call(UpdateUsernameEndpoint(request: request), errorType: Error.self)
  }

  func updateEmail(_ request: UpdateEmailRequest) async throws -> UpdateUserProfileResponse {
    return try await client.call(UpdateEmailEndpoint(request: request), errorType: Error.self)
  }

  func updatePassword(_ request: UpdatePasswordRequest) async throws -> APIMessageResponse {
    return try await client.call(UpdatePasswordEndpoint(request: request), errorType: Error.self)
  }

  func deleteProfile(_ request: DeleteUserProfileRequest) async throws -> DeleteUserProfileResponse {
    _ = request
    return try await client.call(DeleteUserProfileEndpoint(), errorType: Error.self)
  }
}
