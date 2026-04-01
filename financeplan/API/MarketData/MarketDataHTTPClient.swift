import AnyAPI
import Foundation
import OSLog
import StockPlanShared

protocol MarketDataURLSessionProtocol {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: MarketDataURLSessionProtocol {}

private let marketDataHTTPLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
  category: "MarketDataHTTPClient"
)

struct MarketDataHTTPClient {
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
  let session: MarketDataURLSessionProtocol
  let authTokenProvider: () -> String?

  init(
    baseURL: URL,
    session: MarketDataURLSessionProtocol = URLSession.shared,
    authTokenProvider: @escaping () -> String? = { nil }
  ) {
    self.baseURL = baseURL
    self.session = session
    self.authTokenProvider = authTokenProvider
  }

  func fetchCompanyProfile(symbol: String) async throws -> CompanyProfileResponse {
    try await call(GetCompanyProfileEndpoint(symbol: symbol))
  }

  func fetchQuote(symbol: String) async throws -> QuoteResponse {
    try await call(GetQuoteEndpoint(symbol: symbol))
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

    marketDataHTTPLogger.debug(
      "MarketData response [\(endpoint.path, privacy: .public)] status=\(httpResponse.statusCode, privacy: .public)"
    )

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
    let decoder = JSONDecoder.stockPlanShared
    if let stockError = try? decoder.decode(StockPlanShared.APIErrorResponse.self, from: data),
       !stockError.error.isEmpty {
      return stockError.error
    }

    if let stockEnvelope = try? decoder.decode(APIEnvelope<StockPlanShared.APIErrorResponse>.self, from: data) {
      if let nestedError = stockEnvelope.data?.error, !nestedError.isEmpty {
        return nestedError
      }
      if let message = stockEnvelope.message, !message.isEmpty {
        return message
      }
    }

    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      if let error = json["error"] as? String, !error.isEmpty {
        return error
      }
      if let reason = json["reason"] as? String, !reason.isEmpty {
        return reason
      }
      if let message = json["message"] as? String, !message.isEmpty {
        return message
      }
      if let detail = json["detail"] as? String, !detail.isEmpty {
        return detail
      }
    }

    if let body = String(data: data, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !body.isEmpty {
      return body
    }

    return nil
  }

  private func makeURLRequest<E: Endpoint>(for endpoint: E) throws -> URLRequest {
    let normalizedPath = endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let url = baseURL.appendingPathComponent(normalizedPath)

    var request = URLRequest(url: url)
    request.httpMethod = endpoint.method.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let token = authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    for header in endpoint.headers {
      request.setValue(header.value, forHTTPHeaderField: header.name)
    }

    return request
  }
}
