import Foundation
import StockPlanShared
import OSLog
import AnyAPI

/// Protocol for structured error reporting. Implementations can log errors with context.
public protocol ErrorReporting: Sendable {
    func report(_ error: Error, context: [String: String], endpoint: String, method: String, statusCode: Int?)
}

public protocol HTTPClientError: Error, Sendable {
    var statusCode: Int? { get }
}
/// Abstract base class consolidating shared HTTP client logic:
/// - request building (with auth headers and customizable extra headers)
/// - response validation, envelope unwrapping
/// - error mapping, structured logging, retry with exponential backoff
///
/// Subclasses specify their own `Error` type conforming to `LocalizedError & Equatable & Sendable`
/// and override factory methods to produce errors. The base class handles the rest.
public class BaseHTTPClient<ErrorType: LocalizedError & Equatable & Sendable & HTTPClientError>: @unchecked Sendable {
    
    // MARK: - Stored Properties
    
    public let baseURL: URL
    public let session: any HTTPClientSession
    public let authTokenProvider: () -> String?
    public let logger: Logger
    public let errorReporter: ErrorReporting?
    
    let decoder: JSONDecoder
    private let maxRetries: Int
    private let baseRetryDelayMs: Double
    
    // MARK: - Init
    
    public init(
        baseURL: URL,
        session: any HTTPClientSession,
        authTokenProvider: @escaping () -> String? = { nil },
        logger: Logger? = nil,
        errorReporter: ErrorReporting? = nil,
        decoder: JSONDecoder = .stockPlanShared,
        maxRetries: Int = 3,
        baseRetryDelayMs: Double = 800.0
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authTokenProvider = authTokenProvider
        self.logger = logger ?? Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: String(describing: Self.self))
        self.errorReporter = errorReporter
        self.decoder = decoder
        self.maxRetries = maxRetries
        self.baseRetryDelayMs = baseRetryDelayMs
    }
    
    // MARK: - Public Call API
    
    /// Executes an endpoint with retry, envelope unwrapping (APIEnvelope first, then custom via `decodeCustomEnvelope`),
    /// and error mapping.
    public func call<E: Endpoint>(_ endpoint: E) async throws -> E.Response where E.Response: Codable & Sendable {
        var lastError: Error?
        var attempt = 0
        
        while attempt < maxRetries {
            do {
                let data = try await execute(endpoint)
                // Decode: try direct first, then APIEnvelope, then custom envelope
                do {
                    return try endpoint.decode(data)
                } catch {
                    if let envelope = try? decoder.decode(APIEnvelope<E.Response>.self, from: data),
                       let payload = envelope.data {
                        return payload
                    }
                    if let message = (try? decoder.decode(APIEnvelope<E.Response>.self, from: data))?.message, !message.isEmpty {
                        throw makeAPIError(message)
                    }
                    if let customPayload = try decodeCustomEnvelope(data: data, for: endpoint) {
                        return customPayload
                    }
                    throw error
                }
            } catch {
                lastError = error
                let shouldRetry = shouldRetry(error: error, attempt: attempt, endpoint: endpoint)
                if shouldRetry, attempt < maxRetries - 1 {
                    let delay = computeRetryDelay(attempt: attempt)
                    self.logger.debug("Retrying \(endpoint.path) after \(Int(delay))ms (attempt \(attempt + 1)/\(self.maxRetries))")
                    try? await Task.sleep(for: .milliseconds(Int(delay)))
                    attempt += 1
                    continue
                }
                // Final failure — structured logging then throw mapped error
                reportError(error, endpoint: endpoint, attempt: attempt)
                throw makeError(from: error)
            }
        }
        let fallbackError = makeAPIError("Unknown error")
        reportError(fallbackError, endpoint: endpoint, attempt: maxRetries)
        throw makeError(from: fallbackError)
    }
    
    /// Variant that returns both payload and response headers.
    public func callWithHeaders<E: Endpoint>(_ endpoint: E) async throws -> (response: E.Response, headers: HTTPURLResponse) where E.Response: Codable & Sendable {
        var lastError: Error?
        var attempt = 0
        
        while attempt < maxRetries {
            do {
                let (data, httpResponse) = try await executeWithResponse(endpoint)
                do {
                    return (try endpoint.decode(data), httpResponse)
                } catch {
                    if let envelope = try? decoder.decode(APIEnvelope<E.Response>.self, from: data),
                       let payload = envelope.data {
                        return (payload, httpResponse)
                    }
                    if let message = (try? decoder.decode(APIEnvelope<E.Response>.self, from: data))?.message, !message.isEmpty {
                        throw makeAPIError(message)
                    }
                    if let customPayload = try decodeCustomEnvelope(data: data, for: endpoint) {
                        return (customPayload, httpResponse)
                    }
                    throw error
                }
            } catch {
                lastError = error
                let shouldRetry = shouldRetry(error: error, attempt: attempt, endpoint: endpoint)
                if shouldRetry, attempt < maxRetries - 1 {
                    let delay = computeRetryDelay(attempt: attempt)
                    self.logger.debug("Retrying \(endpoint.path) with headers after \(Int(delay))ms")
                    try? await Task.sleep(for: .milliseconds(Int(delay)))
                    attempt += 1
                    continue
                }
                reportError(error, endpoint: endpoint, attempt: attempt)
                throw makeError(from: error)
            }
        }
        let fallbackError = makeAPIError("Unknown error")
        reportError(fallbackError, endpoint: endpoint, attempt: maxRetries)
        throw makeError(from: fallbackError)
    }
    
    /// For endpoints that return no body (204 No Content).
    public func callWithoutResponse<E: Endpoint>(_ endpoint: E) async throws where E.Response: Codable {
        var attempt = 0
        while attempt < maxRetries {
            do {
                _ = try await execute(endpoint)
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
                throw makeError(from: error)
            }
        }
    }
    
    // MARK: - Request Building
    
    /// Constructs a URLRequest from the endpoint. Subclasses can override `extraHeaders` for custom headers.
    open func makeURLRequest<E: Endpoint>(for endpoint: E) throws -> URLRequest where E.Response: Codable {
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
        
        // Authorization
        if let token = authTokenProvider(), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Extra headers from subclass
        for header in extraHeaders(for: endpoint) {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        // Headers defined directly on the endpoint (e.g., API key, custom headers)
        for header in endpoint.headers {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        // Body for non-GET
        if endpoint.method != .get, !parameters.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        }
        
        return request
    }
    
    /// Override to inject additional headers (e.g., MFA capability token).
    open func extraHeaders<E: Endpoint>(for endpoint: E) -> [(name: String, value: String)] {
        []
    }
    
    // MARK: - Network Execution (Protected helpers for subclass reuse)
    
    /// Execute endpoint and return raw data, with validation and retry handled at higher level.
    open func execute<E: Endpoint>(_ endpoint: E) async throws -> Data where E.Response: Codable {
        let request = try makeURLRequest(for: endpoint)
        return try await sendRequest(request)
    }
    
    /// Execute endpoint and return raw data plus HTTPURLResponse.
    open func executeWithResponse<E: Endpoint>(_ endpoint: E) async throws -> (Data, HTTPURLResponse) where E.Response: Codable {
        let request = try makeURLRequest(for: endpoint)
        return try await sendRequestWithResponse(request)
    }
    
    /// Send a raw URLRequest with response validation and error mapping. Used by custom endpoint methods.
    open func sendRequest(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw makeInvalidResponseError()
        }
        try await validateResponse(httpResponse, data: data)
        return data
    }
    
    /// Send a raw URLRequest and return response with headers.
    open func sendRequestWithResponse(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw makeInvalidResponseError()
        }
        try await validateResponse(httpResponse, data: data)
        return (data, httpResponse)
    }
    
    // MARK: - Response Validation
    
    /// Validates the HTTP response and throws appropriate errors.
    open func validateResponse(_ response: HTTPURLResponse, data: Data) async throws {
        guard (200..<300).contains(response.statusCode) else {
            let message = APIErrorDecoding.message(from: data)
            if response.statusCode == 401 {
                throw makeUnauthorizedError(message)
            }
            if let message, !message.isEmpty {
                throw makeAPIError(message)
            }
            throw makeInvalidStatusError(response.statusCode)
        }
    }
    
    // MARK: - Customization Points (Error Factories)
    
    /// Create an `.invalidResponse` error.
    open func makeInvalidResponseError() -> ErrorType {
        fatalError("Subclasses must override makeInvalidResponseError() or provide a concrete ErrorType.")
    }
    
    /// Create an `.invalidStatus` error.
    open func makeInvalidStatusError(_ code: Int) -> ErrorType {
        fatalError("Subclasses must override makeInvalidStatusError(_:) or provide a concrete ErrorType.")
    }
    
    /// Create an `.unauthorized` error.
    open func makeUnauthorizedError(_ message: String?) -> ErrorType {
        fatalError("Subclasses must override makeUnauthorizedError(_:) or provide a concrete ErrorType.")
    }
    
    /// Create an `.api` error.
    open func makeAPIError(_ message: String) -> ErrorType {
        fatalError("Subclasses must override makeAPIError(_:) or provide a concrete ErrorType.")
    }
    
    /// Map any thrown error to the client's Error type (used when retries exhausted).
    open func makeError(from error: Error) -> ErrorType {
        if let typed = error as? ErrorType {
            return typed
        }
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return makeAPIError(message)
    }
    
    // Subclasses may override to provide custom envelope decoding.
    /// Return a decoded payload if the response uses a non-APIEnvelope wrapper, or `nil` to fall back.
    open func decodeCustomEnvelope<E: Endpoint>(data: Data, for endpoint: E) throws -> E.Response? where E.Response: Codable & Sendable {
        nil
    }
    
    // Subclasses may override to customize retry policy.
    /// Default: only retry for safe HTTP methods (GET, HEAD) on URLError or 5xx/429.
    open func shouldRetry(error: Error, attempt: Int, endpoint: any Endpoint) -> Bool {
        // Only retry for idempotent/safe methods to avoid duplicate side effects.
        switch endpoint.method {
        case .get, .head:
            if error is URLError {
                return true
            }
            if let httpError = error as? HTTPClientError, let code = httpError.statusCode {
                if (500...599).contains(code) || code == 429 {
                    return true
                }
            }
            return false
        default:
            // For POST/PUT/PATCH/DELETE etc., do not retry automatically.
            return false
        }
    }
    
    // MARK: - Retry Timing
    
    private func computeRetryDelay(attempt: Int) -> Double {
        let exponential = baseRetryDelayMs * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...exponential * 0.2)
        return exponential + jitter
    }
    
    // MARK: - Structured Logging
    
    private func reportError(_ error: Error, endpoint: any Endpoint, attempt: Int) {
        var context: [String: String] = [
            "endpoint": endpoint.path,
            "method": endpoint.method.rawValue,
            "attempt": String(attempt)
        ]
        if let typed = error as? ErrorType {
            context["errorType"] = String(describing: typed)
        }
        if let httpError = error as? HTTPClientError, let code = httpError.statusCode {
            context["statusCode"] = String(code)
        }
        errorReporter?.report(error, context: context, endpoint: endpoint.path, method: endpoint.method.rawValue, statusCode: (error as? HTTPClientError)?.statusCode)
    }
}
