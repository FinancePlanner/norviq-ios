import AnyAPI
import Foundation
import StockPlanShared
import OSLog

private let stockHTTPLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "StockHTTPClient")

protocol StockURLSessionProtocol {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: StockURLSessionProtocol {}

protocol StockRequestBodyEndpoint {
  func bodyData() throws -> Data?
}

struct StockHTTPClient {
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
  let session: StockURLSessionProtocol
  let authTokenProvider: () -> String?

  init(baseURL: URL, session: StockURLSessionProtocol = URLSession.shared, authTokenProvider: @escaping () -> String? = { nil }) {
    self.baseURL = baseURL
    self.session = session
    self.authTokenProvider = authTokenProvider
  }

  func call<E: Endpoint>(_ endpoint: E) async throws -> E.Response where E.Response: Codable {
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

  func callWithoutResponse<E: Endpoint>(_ endpoint: E) async throws {
    _ = try await perform(endpoint)
  }

  private func perform<E: Endpoint>(_ endpoint: E) async throws -> Data {
    let request = try makeURLRequest(for: endpoint)
    logRequest(request, endpoint: endpoint)
    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw Error.invalidResponse
    }

    stockHTTPLogger.debug("Stock response [\(endpoint.path, privacy: .public)] status=\(httpResponse.statusCode, privacy: .public)")
    logValuationResponseIfNeeded(data, endpointPath: endpoint.path, statusCode: httpResponse.statusCode)

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

  private func logRequest<E: Endpoint>(_ request: URLRequest, endpoint: E) {
    let method = request.httpMethod ?? endpoint.method.rawValue
    let urlString =
      request.url?.absoluteString ?? baseURL.appendingPathComponent(endpoint.path).absoluteString
    stockHTTPLogger.debug(
      "Stock request [\(method, privacy: .public)] \(urlString, privacy: .public)"
    )
  }

  private func errorMessage(from data: Data) -> String? {
    let decoder = JSONDecoder.stockPlanShared
    if let stockError = try? decoder.decode(StockPlanShared.APIErrorResponse.self, from: data), !stockError.error.isEmpty {
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

    if let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
      return body
    }

    return nil
  }

  private func makeURLRequest<E: Endpoint>(for endpoint: E) throws -> URLRequest {
    let normalizedPath = endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    var url = baseURL.appendingPathComponent(normalizedPath)

    var request = URLRequest(url: url)
    request.httpMethod = endpoint.method.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let token = authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    for header in endpoint.headers {
      request.setValue(header.value, forHTTPHeaderField: header.name)
    }

    if endpoint.method == .get {
      let parameters = try endpoint.asParameters()

      if !parameters.isEmpty {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        comps?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: String(describing: $0.value)) }
        if let final = comps?.url { request.url = final }
      }
    } else if let bodyEndpoint = endpoint as? any StockRequestBodyEndpoint {
      request.httpBody = try bodyEndpoint.bodyData()
    } else {
      let parameters = try endpoint.asParameters()

      if !parameters.isEmpty {
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
      }
    }

    logValuationRequestIfNeeded(request, endpointPath: endpoint.path)

    return request
  }

  private func logValuationRequestIfNeeded(_ request: URLRequest, endpointPath: String) {
    guard endpointPath.contains("/stocks/symbol/"), endpointPath.contains("/valuation") else {
      return
    }

    let body = request.httpBody.flatMap {
      String(data: $0, encoding: .utf8)
    } ?? "<empty>"

    stockHTTPLogger.debug(
      "Stock request [\(endpointPath, privacy: .public)] method=\(request.httpMethod ?? "", privacy: .public) body=\(body, privacy: .public)"
    )
  }

  private func logValuationResponseIfNeeded(_ data: Data, endpointPath: String, statusCode: Int) {
    guard endpointPath.contains("/stocks/symbol/"), endpointPath.contains("/valuation") else {
      return
    }

    let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"

    stockHTTPLogger.debug(
      "Stock response [\(endpointPath, privacy: .public)] status=\(statusCode, privacy: .public) body=\(body, privacy: .public)"
    )
  }
}
