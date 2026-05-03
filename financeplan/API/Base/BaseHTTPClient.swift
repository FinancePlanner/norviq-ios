import Foundation
import StockPlanShared
import OSLog
import AnyAPI

/// Protocol for structured error reporting. Implementations can log errors with context.
public protocol ErrorReporting: Sendable {
    func report(_ error: Error, context: [String: String], endpoint: String, method: String, statusCode: Int?)
}

public protocol HTTPClientError: LocalizedError, Equatable, Sendable {
    var statusCode: Int? { get }
    static func makeInvalidResponse() -> Self
    static func makeInvalidStatus(_ code: Int) -> Self
    static func makeUnauthorized(_ message: String?) -> Self
    static func makeAPI(_ message: String) -> Self
}

/// Shared HTTP client logic.
public struct BaseHTTPClient: Sendable {
    
    // MARK: - Stored Properties
    
    public let baseURL: URL
    public let session: any HTTPClientSession
    public let authTokenProvider: @Sendable () -> String?
    public let logger: Logger
    public let errorReporter: ErrorReporting?
    
    public let extraHeadersProvider: @Sendable (any Endpoint) -> [(name: String, value: String)]
    public let requestLogger: @Sendable (String, HTTPMethod, Parameters) -> Void
    
    let decoder: JSONDecoder
    private let maxRetries: Int
    private let baseRetryDelayMs: Double
    
    // MARK: - Init
    
    public init(
        baseURL: URL,
        session: any HTTPClientSession = URLSession.shared,
        authTokenProvider: @escaping @Sendable () -> String? = { nil },
        extraHeadersProvider: @escaping @Sendable (any Endpoint) -> [(name: String, value: String)] = { _ in [] },
        requestLogger: @escaping @Sendable (String, HTTPMethod, Parameters) -> Void = { _, _, _ in },
        logger: Logger? = nil,
        errorReporter: ErrorReporting? = nil,
        decoder: JSONDecoder = .stockPlanShared,
        maxRetries: Int = 3,
        baseRetryDelayMs: Double = 800.0
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider
        self.extraHeadersProvider = extraHeadersProvider
        self.requestLogger = requestLogger
        self.logger = logger ?? Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "HTTPClient")
        self.errorReporter = errorReporter
        self.decoder = decoder
        self.maxRetries = maxRetries
        self.baseRetryDelayMs = baseRetryDelayMs
    }

    // MARK: - Core Request Logic
    
    public func call<E: Endpoint, ErrorType: HTTPClientError>(_ endpoint: E, errorType: ErrorType.Type) async throws -> E.Response where E.Response: Codable & Sendable {
        var attempt = 0
        
        while attempt < maxRetries {
            do {
                let data = try await execute(endpoint, errorType: ErrorType.self)
                do {
                    return try endpoint.decode(data)
                } catch {
                    if let envelope = try? decoder.decode(APIEnvelope<E.Response>.self, from: data),
                       let payload = envelope.data {
                        return payload
                    }
                    if let message = (try? decoder.decode(APIEnvelope<E.Response>.self, from: data))?.message, !message.isEmpty {
                        throw ErrorType.makeAPI(message)
                    }
                    throw error
                }
            } catch {
                let shouldRetry = shouldRetry(error: error, attempt: attempt, endpoint: endpoint)
                if shouldRetry, attempt < maxRetries - 1 {
                    let delay = computeRetryDelay(attempt: attempt)
                    self.logger.debug("Retrying \(endpoint.path) after \(Int(delay))ms (attempt \(attempt + 1)/\(self.maxRetries))")
                    try? await Task.sleep(for: .milliseconds(Int(delay)))
                    attempt += 1
                    continue
                }
                reportError(error, endpoint: endpoint, attempt: attempt)
                throw makeError(from: error, to: ErrorType.self)
            }
        }
        let fallbackError = ErrorType.makeAPI("Unknown error")
        reportError(fallbackError, endpoint: endpoint, attempt: maxRetries)
        throw fallbackError
    }
    
    public func callWithHeaders<E: Endpoint, ErrorType: HTTPClientError>(_ endpoint: E, errorType: ErrorType.Type) async throws -> (response: E.Response, headers: HTTPURLResponse) where E.Response: Codable & Sendable {
        var attempt = 0
        while attempt < maxRetries {
            do {
                let (data, httpResponse) = try await executeWithResponse(endpoint, errorType: ErrorType.self)
                do {
                    return (try endpoint.decode(data), httpResponse)
                } catch {
                    if let envelope = try? decoder.decode(APIEnvelope<E.Response>.self, from: data),
                       let payload = envelope.data {
                        return (payload, httpResponse)
                    }
                    if let message = (try? decoder.decode(APIEnvelope<E.Response>.self, from: data))?.message, !message.isEmpty {
                        throw ErrorType.makeAPI(message)
                    }
                    throw error
                }
            } catch {
                let shouldRetry = shouldRetry(error: error, attempt: attempt, endpoint: endpoint)
                if shouldRetry, attempt < maxRetries - 1 {
                    let delay = computeRetryDelay(attempt: attempt)
                    try? await Task.sleep(for: .milliseconds(Int(delay)))
                    attempt += 1
                    continue
                }
                reportError(error, endpoint: endpoint, attempt: attempt)
                throw makeError(from: error, to: ErrorType.self)
            }
        }
        let fallbackError = ErrorType.makeAPI("Unknown error")
        reportError(fallbackError, endpoint: endpoint, attempt: maxRetries)
        throw fallbackError
    }
    
    public func callWithoutResponse<E: Endpoint, ErrorType: HTTPClientError>(_ endpoint: E, errorType: ErrorType.Type) async throws where E.Response: Codable {
        var attempt = 0
        while attempt < maxRetries {
            do {
                _ = try await execute(endpoint, errorType: ErrorType.self)
                return
            } catch {
                let shouldRetry = shouldRetry(error: error, attempt: attempt, endpoint: endpoint)
                if shouldRetry, attempt < maxRetries - 1 {
                    let delay = computeRetryDelay(attempt: attempt)
                    try? await Task.sleep(for: .milliseconds(Int(delay)))
                    attempt += 1
                    continue
                }
                reportError(error, endpoint: endpoint, attempt: attempt)
                throw makeError(from: error, to: ErrorType.self)
            }
        }
    }
    
    // MARK: - Request Building
    
    public func makeURLRequest<E: Endpoint>(for endpoint: E) throws -> URLRequest where E.Response: Codable {
        let normalizedPath = endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let base = baseURL.appendingPathComponent(normalizedPath)
        let parameters = try endpoint.asParameters()
        
        var urlComponents: URLComponents?
        if endpoint.method == .get, !parameters.isEmpty {
            urlComponents = URLComponents(url: base, resolvingAgainstBaseURL: false)
            urlComponents?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: String(describing: $0.value)) }
        }
        let finalURL = urlComponents?.url ?? base
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        for header in extraHeadersProvider(endpoint) {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        for header in endpoint.headers {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        if endpoint.method != .get, !parameters.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        }
        
        requestLogger(endpoint.path, endpoint.method, parameters)
        
        return request
    }
    
    // MARK: - Network Execution
    
    public func execute<E: Endpoint, ErrorType: HTTPClientError>(_ endpoint: E, errorType: ErrorType.Type) async throws -> Data where E.Response: Codable {
        let request = try makeURLRequest(for: endpoint)
        return try await sendRequest(request, errorType: ErrorType.self)
    }
    
    public func executeWithResponse<E: Endpoint, ErrorType: HTTPClientError>(_ endpoint: E, errorType: ErrorType.Type) async throws -> (Data, HTTPURLResponse) where E.Response: Codable {
        let request = try makeURLRequest(for: endpoint)
        return try await sendRequestWithResponse(request, errorType: ErrorType.self)
    }
    
    public func sendRequest<ErrorType: HTTPClientError>(_ request: URLRequest, errorType: ErrorType.Type) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ErrorType.makeInvalidResponse()
        }
        try await validateResponse(httpResponse, data: data, errorType: ErrorType.self)
        return data
    }
    
    public func sendRequestWithResponse<ErrorType: HTTPClientError>(_ request: URLRequest, errorType: ErrorType.Type) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ErrorType.makeInvalidResponse()
        }
        try await validateResponse(httpResponse, data: data, errorType: ErrorType.self)
        return (data, httpResponse)
    }
    
    public func validateResponse<ErrorType: HTTPClientError>(_ response: HTTPURLResponse, data: Data, errorType: ErrorType.Type) async throws {
        guard (200..<300).contains(response.statusCode) else {
            let message = APIErrorDecoding.message(from: data)
            if response.statusCode == 401 {
                throw ErrorType.makeUnauthorized(message)
            }
            if let message, !message.isEmpty {
                throw ErrorType.makeAPI(message)
            }
            throw ErrorType.makeInvalidStatus(response.statusCode)
        }
    }
    
    public func makeError<ErrorType: HTTPClientError>(from error: Error, to type: ErrorType.Type) -> ErrorType {
        if let typed = error as? ErrorType {
            return typed
        }
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return ErrorType.makeAPI(message)
    }
    
    public func shouldRetry(error: Error, attempt: Int, endpoint: any Endpoint) -> Bool {
        switch endpoint.method {
        case .get, .head:
            if error is URLError {
                return true
            }
            if let httpError = error as? any HTTPClientError, let code = httpError.statusCode {
                if (500...599).contains(code) || code == 429 {
                    return true
                }
            }
            return false
        default:
            return false
        }
    }
    
    private func computeRetryDelay(attempt: Int) -> Double {
        let exponential = baseRetryDelayMs * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...exponential * 0.2)
        return exponential + jitter
    }
    
    private func reportError(_ error: Error, endpoint: any Endpoint, attempt: Int) {
        var context: [String: String] = [
            "endpoint": endpoint.path,
            "method": endpoint.method.rawValue,
            "attempt": String(attempt)
        ]
        if let httpError = error as? any HTTPClientError, let code = httpError.statusCode {
            context["statusCode"] = String(code)
        }
        errorReporter?.report(error, context: context, endpoint: endpoint.path, method: endpoint.method.rawValue, statusCode: (error as? any HTTPClientError)?.statusCode)
    }
}
