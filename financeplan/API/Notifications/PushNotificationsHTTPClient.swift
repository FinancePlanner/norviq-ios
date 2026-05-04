import AnyAPI
import Foundation
import StockPlanShared
import OSLog

protocol PushNotificationsURLSessionProtocol: HTTPClientSession {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: PushNotificationsURLSessionProtocol {}

// MARK: - Client

struct PushNotificationsHTTPClient: Sendable {
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

  init(baseURL: URL, session: any HTTPClientSession = URLSession.shared, authTokenProvider: @escaping @Sendable () async -> String? = { nil }) {
    self.client = BaseHTTPClient(
        baseURL: baseURL,
        session: session,
        authTokenProvider: authTokenProvider,
        logger: Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "PushNotificationsHTTPClient"),
        decoder: .stockPlanShared
    )
  }

  func registerDevice(_ payload: PushDeviceRegistrationRequest) async throws -> PushDeviceRegistrationResponse {
    let endpoint = CustomEndpoint(path: "/v1/notifications/apns/device", method: .put, payload: payload)
    let request = try await client.makeURLRequest(for: endpoint)
    let data = try await client.sendRequest(request, errorType: Error.self)

    do {
      return try JSONDecoder.stockPlanShared.decode(PushDeviceRegistrationResponse.self, from: data)
    } catch {
      if let envelope = try? JSONDecoder.stockPlanShared.decode(APIEnvelope<PushDeviceRegistrationResponse>.self, from: data),
         let payload = envelope.data {
        return payload
      }
      throw error
    }
  }

  func deactivateDevice(_ payload: PushDeviceDeactivateRequest) async throws {
    let endpoint = CustomEndpoint(path: "/v1/notifications/apns/device/deactivate", method: .post, payload: payload)
    let request = try await client.makeURLRequest(for: endpoint)
    _ = try await client.sendRequest(request, errorType: Error.self)
  }
}

private struct CustomEndpoint<T: Encodable>: Endpoint {
    typealias Response = EmptyAPIResponse
    let path: String
    let method: HTTPMethod
    let payload: T
    
    func asParameters() throws -> Parameters {
        let data = try JSONEncoder.stockPlanShared.encode(payload)
        return (try JSONSerialization.jsonObject(with: data) as? Parameters) ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(path, forKey: .path)
        try container.encode(method.rawValue, forKey: .method)
        try container.encode(payload, forKey: .payload)
    }
    
    private enum CodingKeys: String, CodingKey {
        case path, method, payload
    }
}
