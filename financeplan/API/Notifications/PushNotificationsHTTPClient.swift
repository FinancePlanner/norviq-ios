import Foundation
import StockPlanShared

protocol PushNotificationsURLSessionProtocol {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: PushNotificationsURLSessionProtocol {}

struct PushNotificationsHTTPClient {
  enum Error: LocalizedError, Equatable {
    case invalidResponse
    case invalidStatus(Int)
    case unauthorized(String?)
    case api(String)

    var errorDescription: String? {
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
  }

  let baseURL: URL
  let session: PushNotificationsURLSessionProtocol
  let authTokenProvider: () -> String?

  init(
    baseURL: URL,
    session: PushNotificationsURLSessionProtocol = URLSession.shared,
    authTokenProvider: @escaping () -> String? = { nil }
  ) {
    self.baseURL = baseURL
    self.session = session
    self.authTokenProvider = authTokenProvider
  }

  func registerDevice(_ payload: PushDeviceRegistrationRequest) async throws -> PushDeviceRegistrationResponse {
    let request = try makeRequest(
      path: "/v1/notifications/apns/device",
      method: "PUT",
      body: payload
    )
    let data = try await perform(request: request)

    do {
      return try JSONDecoder.stockPlanShared.decode(PushDeviceRegistrationResponse.self, from: data)
    } catch {
      if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let nestedPayload = json["data"],
         JSONSerialization.isValidJSONObject(nestedPayload),
         let nestedData = try? JSONSerialization.data(withJSONObject: nestedPayload),
         let payload = try? JSONDecoder.stockPlanShared.decode(PushDeviceRegistrationResponse.self, from: nestedData)
      {
        return payload
      }
      throw error
    }
  }

  func deactivateDevice(_ payload: PushDeviceDeactivateRequest) async throws {
    let request = try makeRequest(
      path: "/v1/notifications/apns/device/deactivate",
      method: "POST",
      body: payload
    )
    _ = try await perform(request: request)
  }

  private func makeRequest<T: Encodable>(
    path: String,
    method: String,
    body: T
  ) throws -> URLRequest {
    let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let url = baseURL.appendingPathComponent(normalizedPath)

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let token = authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    request.httpBody = try JSONEncoder.stockPlanShared.encode(body)
    return request
  }

  private func perform(request: URLRequest) async throws -> Data {
    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw Error.invalidResponse
    }

    guard (200 ..< 300).contains(httpResponse.statusCode) else {
      let message = errorMessage(from: data)
      if httpResponse.statusCode == 401 {
        throw Error.unauthorized(message)
      }
      if let message, !message.isEmpty {
        throw Error.api(message)
      }
      throw Error.invalidStatus(httpResponse.statusCode)
    }

    return data
  }

  private func errorMessage(from data: Data) -> String? {
    APIErrorDecoding.message(from: data)
  }
}
