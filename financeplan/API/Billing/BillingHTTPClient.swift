import AnyAPI
import Foundation
import OSLog
import StockPlanShared

private let billingHTTPLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
  category: "BillingHTTPClient"
)

protocol BillingURLSessionProtocol: HTTPClientSession {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: BillingURLSessionProtocol {}

struct BillingHTTPClient {
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
  let session: BillingURLSessionProtocol
  let authTokenProvider: () -> String?

  init(
    baseURL: URL,
    session: BillingURLSessionProtocol = URLSession.shared,
    authTokenProvider: @escaping () -> String? = { nil }
  ) {
    self.baseURL = baseURL
    self.session = session
    self.authTokenProvider = authTokenProvider
  }

  func fetchContext() async throws -> BillingContextResponse {
    try await call(GetBillingContextEndpoint())
  }

  func restorePurchases() async throws -> BillingContextResponse {
    try await call(RestoreBillingEndpoint())
  }

  func redeemCoupon(code: String) async throws -> BillingCouponRedemptionResponse {
    try await call(RedeemBillingCouponEndpoint(code: code))
  }

  private func call<E: Endpoint>(_ endpoint: E) async throws -> E.Response where E.Response: Codable {
    let data = try await perform(endpoint)
    do {
      return try endpoint.decode(data)
    } catch {
      if let envelope = try? endpoint.decoder.decode(BillingHTTPEnvelope<E.Response>.self, from: data) {
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

    billingHTTPLogger.debug(
      "Billing response [\(endpoint.path, privacy: .public)] status=\(httpResponse.statusCode, privacy: .public)"
    )

    guard (200 ..< 300).contains(httpResponse.statusCode) else {
      let message = APIErrorDecoding.message(from: data)
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
    let url = baseURL.appendingPathComponent(normalizedPath)
    let parameters = try endpoint.asParameters()

    var request = URLRequest(url: url)
    request.httpMethod = endpoint.method.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let token = authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    if endpoint.method == .get, !parameters.isEmpty {
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: String(describing: $0.value)) }
      if let final = components?.url {
        request.url = final
      }
    } else if !parameters.isEmpty {
      request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
    }

    return request
  }
}

private struct BillingHTTPEnvelope<T: Codable>: Codable {
  let data: T?
  let message: String?
}
