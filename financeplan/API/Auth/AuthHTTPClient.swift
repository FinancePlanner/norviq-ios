import AnyAPI
import Foundation
import OSLog
import StockPlanShared

// MARK: - Client

final class AuthHTTPClient: Sendable {
    
    // MARK: - Static Constants
    
    nonisolated(unsafe) private static let mfaCapabilityHeader = "X-StockPlan-Client-Capabilities"
    nonisolated(unsafe) private static let mfaCapabilityToken = "mfa-auth-v1"
    private static let dbStyleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()
    private static let decoder: JSONDecoder = .stockPlanShared
    
    // MARK: - Error Type
    
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
            if case .unauthorized = self { return true }
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
    private let logger: Logger

    // MARK: - Init
    
    init(baseURL: URL, session: any HTTPClientSession = URLSession.shared, authTokenProvider: @escaping @Sendable () -> String? = { nil }) {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "AuthHTTPClient")
        self.logger = logger
        self.client = BaseHTTPClient(
            baseURL: baseURL,
            session: session,
            authTokenProvider: authTokenProvider,
            extraHeadersProvider: { endpoint in
                var headers: [(String, String)] = []
                if endpoint.path == "/v1/auth/login"
                    || (endpoint.path.contains("/oauth/") && endpoint.path.hasSuffix("/exchange"))
                    || endpoint.path == "/v1/auth/mfa/verify"
                    || endpoint.path == "/v1/auth/mfa/resend"
                {
                    headers.append((Self.mfaCapabilityHeader, Self.mfaCapabilityToken))
                }
                return headers
            },
            requestLogger: { [logger] path, method, parameters in
                AuthHTTPClient.logRequest(logger: logger, endpointPath: path, method: method, parameters: parameters)
            },
            logger: logger,
            decoder: .stockPlanShared
        )
    }
    
    // MARK: - Public API (delegated)
    
    func login(_ request: AuthLoginRequest) async throws -> AuthLoginOutcomePayload {
        let endpoint = LoginEndpoint(email: request.email, password: request.password)
        let data = try await client.execute(endpoint, errorType: Error.self)
        return try decodeLoginOutcome(from: data)
    }
    
    func register(_ request: AuthRegisterRequest, confirmPassword: String? = nil) async throws {
        try await register(
            username: request.username,
            email: request.email,
            password: request.password,
            dateOfBirth: request.dateOfBirth,
            confirmPassword: confirmPassword ?? request.password
        )
    }
    
    func register(
        username: String,
        email: String,
        password: String,
        dateOfBirth: Date,
        confirmPassword: String
    ) async throws {
        let endpoint = SignupEndpoint(
            username: username,
            email: email,
            password: password,
            confirmPassword: confirmPassword,
            dateOfBirth: dateOfBirth
        )
        try await client.callWithoutResponse(endpoint, errorType: Error.self)
    }
    
    func forgotPassword(_ request: AuthForgotPasswordRequest) async throws -> AuthForgotPasswordResponse {
        let endpoint = ForgotPasswordEndpoint(email: request.email)
        return try await client.call(endpoint, errorType: Error.self)
    }
    
    func refresh(_ request: AuthRefreshRequest) async throws -> AuthResponse {
        let endpoint = RefreshEndpoint(refreshToken: request.refreshToken)
        let data = try await client.execute(endpoint, errorType: Error.self)
        return try decodeAuthResponse(from: data)
    }
    
    func oauthStart(provider: OAuthProviderKind, redirectURI: String) async throws -> OAuthStartResponsePayload {
        let endpoint = OAuthStartEndpoint(provider: provider, redirectURI: redirectURI)
        return try await client.call(endpoint, errorType: Error.self)
    }
    
    func oauthExchange(
        provider: OAuthProviderKind,
        request: OAuthExchangeRequestPayload
    ) async throws -> AuthLoginOutcomePayload {
        let endpoint = OAuthExchangeEndpoint(provider: provider, payload: request)
        let data = try await client.execute(endpoint, errorType: Error.self)
        return try decodeLoginOutcome(from: data)
    }
    
    func verifyMFA(_ request: AuthMFAVerifyRequestPayload) async throws -> AuthResponse {
        let endpoint = MFAVerifyEndpoint(payload: request)
        let data = try await client.execute(endpoint, errorType: Error.self)
        return try decodeAuthResponse(from: data)
    }
    
    func resendMFA(_ request: AuthMFAResendRequestPayload) async throws -> AuthMFAChallengeResponsePayload {
        let endpoint = MFAResendEndpoint(payload: request)
        return try await client.call(endpoint, errorType: Error.self)
    }
    
    func logout(_ request: AuthRefreshRequest) async throws {
        let primary = LogoutEndpoint(refreshToken: request.refreshToken, endpointPath: "/v2/logout")
        do {
            try await client.callWithoutResponse(primary, errorType: Error.self)
        } catch let error as Error where error == .invalidStatus(404) {
            // Backward-compatible fallback while servers migrate endpoint versions.
            let fallback = LogoutEndpoint(refreshToken: request.refreshToken, endpointPath: "/auth/logout")
            try await client.callWithoutResponse(fallback, errorType: Error.self)
        }
    }
    
    // MARK: - Private Helpers
    
    private func decodeAuthResponse(from data: Data) throws -> AuthResponse {
        do {
            return try Self.decoder.decode(AuthResponse.self, from: data)
        } catch {
            if let envelope = try? Self.decoder.decode(APIEnvelope<AuthResponse>.self, from: data),
               let payload = envelope.data {
                return payload
            }
            if let payload = try? decodeAuthResponseFallback(from: data) {
                return payload
            }
            throw error
        }
    }
    
    private func decodeLoginOutcome(from data: Data) throws -> AuthLoginOutcomePayload {
        if let outcome = try? Self.decoder.decode(AuthLoginOutcomePayload.self, from: data) {
            return outcome
        }
        if let envelope = try? Self.decoder.decode(APIEnvelope<AuthLoginOutcomePayload>.self, from: data),
           let payload = envelope.data {
            return payload
        }
        if let auth = try? decodeAuthResponse(from: data) {
            return .authenticated(auth)
        }
        
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let root = jsonObject as? [String: Any] else {
            throw Error.invalidResponse
        }
        
        let payload = (root["data"] as? [String: Any]) ?? root
        let statusRaw = (payload["status"] as? String ?? payload["kind"] as? String ?? "").lowercased()
        guard statusRaw == AuthLoginOutcomeStatusPayload.mfaRequired.rawValue else {
            throw Error.invalidResponse
        }
        guard let mfaObject = payload["mfa"] as? [String: Any] ?? payload["challenge"] as? [String: Any] else {
            throw Error.invalidResponse
        }
        
        guard
            let idRaw = mfaObject["challengeId"] as? String ?? mfaObject["challenge_id"] as? String,
            let challengeID = UUID(uuidString: idRaw),
            let channelRaw = mfaObject["channel"] as? String,
            let channel = AuthMFAChannelPayload(rawValue: channelRaw),
            let masked = mfaObject["maskedDestination"] as? String ?? mfaObject["masked_destination"] as? String
        else {
            throw Error.invalidResponse
        }
        
        let expiresIn = (mfaObject["expiresIn"] as? Int)
            ?? (mfaObject["expires_in"] as? Int)
            ?? 0
        let resendAvailableIn = (mfaObject["resendAvailableIn"] as? Int)
            ?? (mfaObject["resend_available_in"] as? Int)
            ?? 0
        
        return .mfaRequired(
            AuthMFAChallengeResponsePayload(
                challengeId: challengeID,
                channel: channel,
                maskedDestination: masked,
                expiresIn: expiresIn,
                resendAvailableIn: resendAvailableIn
            )
        )
    }
    
    private func decodeAuthResponseFallback(from data: Data) throws -> AuthResponse {
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let root = jsonObject as? [String: Any] else {
            throw Error.invalidResponse
        }
        
        let payload: [String: Any]
        if let nested = root["data"] as? [String: Any] {
            payload = nested
        } else {
            payload = root
        }
        
        return try AuthResponse(
            token: requireString(in: payload, camel: "token"),
            userId: requireUUID(in: payload, camel: "userId", snake: "user_id"),
            expiresIn: requireInt(in: payload, camel: "expiresIn", snake: "expires_in"),
            refreshToken: requireString(in: payload, camel: "refreshToken", snake: "refresh_token"),
            refreshExpiresIn: requireInt(in: payload, camel: "refreshExpiresIn", snake: "refresh_expires_in"),
            username: requireString(in: payload, camel: "username"),
            email: requireString(in: payload, camel: "email"),
            dateOfBirth: requireDate(in: payload, camel: "dateOfBirth", snake: "date_of_birth")
        )
    }
    
    private func requireString(in payload: [String: Any], camel: String, snake: String? = nil) throws -> String {
        if let value = payload[camel] as? String {
            return value
        }
        if let snake, let value = payload[snake] as? String {
            return value
        }
        throw Error.invalidResponse
    }
    
    private func requireUUID(in payload: [String: Any], camel: String, snake: String? = nil) throws -> UUID {
        let raw = try requireString(in: payload, camel: camel, snake: snake)
        guard let uuid = UUID(uuidString: raw) else {
            throw Error.invalidResponse
        }
        return uuid
    }
    
    private func requireInt(in payload: [String: Any], camel: String, snake: String? = nil) throws -> Int {
        if let value = payload[camel] as? Int {
            return value
        }
        if let snake, let value = payload[snake] as? Int {
            return value
        }
        if let value = payload[camel] as? NSNumber {
            return value.intValue
        }
        if let snake, let value = payload[snake] as? NSNumber {
            return value.intValue
        }
        if let value = payload[camel] as? String, let parsed = Int(value) {
            return parsed
        }
        if let snake, let value = payload[snake] as? String, let parsed = Int(value) {
            return parsed
        }
        throw Error.invalidResponse
    }
    
    private func requireDate(in payload: [String: Any], camel: String, snake: String? = nil) throws -> Date {
        if let value = payload[camel], let parsed = parseDate(value) {
            return parsed
        }
        if let snake, let value = payload[snake], let parsed = parseDate(value) {
            return parsed
        }
        throw Error.invalidResponse
    }
    
    private func parseDate(_ rawValue: Any) -> Date? {
        switch rawValue {
        case let value as String:
            if let parsed = ISO8601DateFormatter().date(from: value) {
                return parsed
            }
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = fractionalFormatter.date(from: value) {
                return parsed
            }
            if let parsed = Self.dbStyleDateFormatter.date(from: value) {
                return parsed
            }
            if let parsed = DateFormatter.yyyyMMdd.date(from: value) {
                return parsed
            }
            if let seconds = Double(value) {
                return parseNumericDate(seconds)
            }
            return nil
        case let value as NSNumber:
            return parseNumericDate(value.doubleValue)
        default:
            return nil
        }
    }
    
    private func parseNumericDate(_ rawValue: Double) -> Date {
        if abs(rawValue) >= 1_000_000_000 {
            return Date(timeIntervalSince1970: rawValue)
        }
        return Date(timeIntervalSinceReferenceDate: rawValue)
    }
    
    nonisolated private static func logRequest(logger: Logger, endpointPath: String, method: HTTPMethod, parameters: Parameters) {
        guard endpointPath == "/v1/auth/login" || endpointPath == "/auth/register" else {
            return
        }
        
        var masked = parameters
        for key in masked.keys {
            let lower = key.lowercased()
            if lower.contains("password") || lower.contains("token") {
                masked[key] = "***"
            }
        }
        
        let payloadDescription: String
        if let data = try? JSONSerialization.data(withJSONObject: masked, options: [.sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            payloadDescription = json
        } else {
            payloadDescription = "\(masked)"
        }
        
        logger.debug(
            "Auth request [\(method.rawValue, privacy: .public) \(endpointPath, privacy: .public)] body=\(payloadDescription, privacy: .public)"
        )
    }
}
