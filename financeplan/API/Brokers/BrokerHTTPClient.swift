import AnyAPI
import Foundation
import StockPlanShared

struct BrokerHTTPClient {
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
  let session: URLSession
  let authTokenProvider: () -> String?

  init(
    baseURL: URL,
    session: URLSession = .shared,
    authTokenProvider: @escaping () -> String? = { nil }
  ) {
    self.baseURL = baseURL
    self.session = session
    self.authTokenProvider = authTokenProvider
  }

  func getBrokers() async throws -> [BrokerConnectionResponse] {
    try await call(GetBrokersEndpoint())
  }

  func getBroker(provider: String) async throws -> BrokerConnectionResponse {
    try await call(GetBrokerEndpoint(provider: provider))
  }

  func syncIBKR() async throws -> BrokerSyncResponse {
    try await call(SyncIBKREndpoint())
  }

  private func call<E: Endpoint>(_ endpoint: E) async throws -> E.Response where E.Response: Codable {
    let data = try await perform(endpoint)
    do {
      return try endpoint.decode(data)
    } catch {
      if let envelope = try? endpoint.decoder.decode(APIEnvelope<E.Response>.self, from: data) {
        if let payload = envelope.data {
          return payload
        }
        if let message = envelope.message, !message.isEmpty {
          throw Error.api(message)
        }
      }
      throw error
    }
  }

  private func perform<E: Endpoint>(_ endpoint: E) async throws -> Data {
    let request = try makeURLRequest(for: endpoint)
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

  private func makeURLRequest<E: Endpoint>(for endpoint: E) throws -> URLRequest {
    let normalizedPath = endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    var request = URLRequest(url: baseURL.appendingPathComponent(normalizedPath))
    request.httpMethod = endpoint.method.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let token = authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    let parameters = try endpoint.asParameters()
    if endpoint.method == .get, !parameters.isEmpty {
      var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
      components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: String(describing: $0.value)) }
      if let final = components?.url {
        request.url = final
      }
    } else if !parameters.isEmpty {
      request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
    }

    return request
  }

  private func errorMessage(from data: Data) -> String? {
    let decoder = JSONDecoder.stockPlanShared
    if let stockError = try? decoder.decode(StockPlanShared.APIErrorResponse.self, from: data),
       !stockError.error.isEmpty {
      return stockError.error
    }

    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      if let error = json["error"] as? String, !error.isEmpty { return error }
      if let reason = json["reason"] as? String, !reason.isEmpty { return reason }
      if let message = json["message"] as? String, !message.isEmpty { return message }
    }
    return nil
  }
}
