import Foundation

public struct AuthRegisterRequest: Codable, Sendable, Equatable {
    public let username: String
    public let password: String
    public let confirmPassword: String
    public let email: String
    public let dateOfBirth: Date

    public init(
        username: String,
        password: String,
        confirmPassword: String,
        email: String,
        dateOfBirth: Date
    ) {
        self.username = username
        self.password = password
        self.confirmPassword = confirmPassword
        self.email = email
        self.dateOfBirth = dateOfBirth
    }

    private enum CodingKeys: String, CodingKey {
        case username, password, confirmPassword, email, dateOfBirth
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        username = try container.decode(String.self, forKey: .username)
        password = try container.decode(String.self, forKey: .password)
        confirmPassword = try container.decode(String.self, forKey: .confirmPassword)
        email = try container.decode(String.self, forKey: .email)
        dateOfBirth = try SharedDateDecoder.decodeDate(from: container, forKey: .dateOfBirth)
    }
}

public struct AuthLoginRequest: Codable, Sendable, Equatable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

public enum AuthMFAChannel: String, Codable, Sendable, Equatable {
    case email
    case sms
}

public struct AuthMFAChallengeResponse: Codable, Sendable, Equatable {
    public let challengeId: UUID
    public let channel: AuthMFAChannel
    public let maskedDestination: String
    public let expiresIn: Int
    public let resendAvailableIn: Int

    public init(
        challengeId: UUID,
        channel: AuthMFAChannel,
        maskedDestination: String,
        expiresIn: Int,
        resendAvailableIn: Int
    ) {
        self.challengeId = challengeId
        self.channel = channel
        self.maskedDestination = maskedDestination
        self.expiresIn = expiresIn
        self.resendAvailableIn = resendAvailableIn
    }
}

public struct AuthMFAVerifyRequest: Codable, Sendable, Equatable {
    public let challengeId: UUID
    public let code: String

    public init(challengeId: UUID, code: String) {
        self.challengeId = challengeId
        self.code = code
    }
}

public struct AuthMFAResendRequest: Codable, Sendable, Equatable {
    public let challengeId: UUID

    public init(challengeId: UUID) {
        self.challengeId = challengeId
    }
}

public enum AuthLoginOutcomeStatus: String, Codable, Sendable, Equatable {
    case authenticated
    case mfaRequired
}

public struct AuthLoginOutcome: Codable, Sendable, Equatable {
    public let status: AuthLoginOutcomeStatus
    public let auth: AuthResponse?
    public let mfa: AuthMFAChallengeResponse?

    public init(
        status: AuthLoginOutcomeStatus,
        auth: AuthResponse? = nil,
        mfa: AuthMFAChallengeResponse? = nil
    ) {
        self.status = status
        self.auth = auth
        self.mfa = mfa
    }

    public static func authenticated(_ auth: AuthResponse) -> AuthLoginOutcome {
        AuthLoginOutcome(status: .authenticated, auth: auth, mfa: nil)
    }

    public static func mfaRequired(_ challenge: AuthMFAChallengeResponse) -> AuthLoginOutcome {
        AuthLoginOutcome(status: .mfaRequired, auth: nil, mfa: challenge)
    }
}

public struct AuthResponse: Codable, Sendable, Equatable {
    public let token: String
    public let userId: UUID
    public let expiresIn: Int
    public let refreshToken: String
    public let refreshExpiresIn: Int
    public let username: String
    public let email: String
    public let dateOfBirth: Date

    public init(
        token: String,
        userId: UUID,
        expiresIn: Int,
        refreshToken: String,
        refreshExpiresIn: Int,
        username: String,
        email: String,
        dateOfBirth: Date
    ) {
        self.token = token
        self.userId = userId
        self.expiresIn = expiresIn
        self.refreshToken = refreshToken
        self.refreshExpiresIn = refreshExpiresIn
        self.username = username
        self.email = email
        self.dateOfBirth = dateOfBirth
    }
}

/// Compatibility alias for endpoint layers that use API-style response names.
public typealias APIAuth = AuthResponse
public typealias AuthRegisterResponse = AuthResponse

public struct AuthUserResponse: Codable, Sendable, Equatable {
    public let id: String
    public let username: String
    public let email: String
    public let dateOfBirth: Date

    public init(
        id: String,
        username: String,
        email: String,
        dateOfBirth: Date
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.dateOfBirth = dateOfBirth
    }
}

public struct AuthForgotPasswordRequest: Codable, Sendable, Equatable {
    public let email: String

    public init(email: String) {
        self.email = email
    }
}

public struct AuthForgotPasswordResponse: Codable, Sendable, Equatable {
    public let message: String
    public let resetCode: String?

    public init(message: String, resetCode: String?) {
        self.message = message
        self.resetCode = resetCode
    }
}

public struct AuthResetPasswordRequest: Codable, Sendable, Equatable {
    public let email: String
    public let code: String
    public let newPassword: String

    public init(email: String, code: String, newPassword: String) {
        self.email = email
        self.code = code
        self.newPassword = newPassword
    }
}

public struct AuthRefreshRequest: Codable, Sendable, Equatable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

public enum OAuthProvider: String, Codable, Sendable {
    case apple
    case google
    case x
}

public struct OAuthLinkedAccount: Codable, Sendable, Equatable {
    public let provider: OAuthProvider
    public let connected: Bool
    public let email: String?
    public let emailVerified: Bool
    public let connectedAt: Date?

    public init(
        provider: OAuthProvider,
        connected: Bool,
        email: String? = nil,
        emailVerified: Bool,
        connectedAt: Date? = nil
    ) {
        self.provider = provider
        self.connected = connected
        self.email = email
        self.emailVerified = emailVerified
        self.connectedAt = connectedAt
    }
}

public struct OAuthLinkedAccountsResponse: Codable, Sendable, Equatable {
    public let accounts: [OAuthLinkedAccount]

    public init(accounts: [OAuthLinkedAccount]) {
        self.accounts = accounts
    }
}

public struct OAuthLinkResponse: Codable, Sendable, Equatable {
    public let provider: OAuthProvider
    public let connected: Bool
    public let email: String?
    public let message: String

    public init(provider: OAuthProvider, connected: Bool, email: String? = nil, message: String) {
        self.provider = provider
        self.connected = connected
        self.email = email
        self.message = message
    }
}

public struct OAuthStartRequest: Codable, Sendable, Equatable {
    public let redirectURI: String

    public init(redirectURI: String) {
        self.redirectURI = redirectURI
    }

    private enum CodingKeys: String, CodingKey {
        case redirectURI
        case redirectUri
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let redirectURI = try container.decodeIfPresent(String.self, forKey: .redirectURI)
            ?? container.decodeIfPresent(String.self, forKey: .redirectUri)
        {
            self.redirectURI = redirectURI
            return
        }

        throw DecodingError.keyNotFound(
            CodingKeys.redirectURI,
            .init(codingPath: decoder.codingPath, debugDescription: "Missing redirectURI")
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(redirectURI, forKey: .redirectURI)
    }
}

public struct OAuthStartResponse: Codable, Sendable, Equatable {
    public let flowId: UUID
    public let authorizationURL: String
    public let expiresIn: Int

    public init(flowId: UUID, authorizationURL: String, expiresIn: Int) {
        self.flowId = flowId
        self.authorizationURL = authorizationURL
        self.expiresIn = expiresIn
    }

    private enum CodingKeys: String, CodingKey {
        case flowId
        case authorizationURL
        case authorizationUrl
        case expiresIn
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        flowId = try container.decode(UUID.self, forKey: .flowId)
        if let authorizationURL = try container.decodeIfPresent(String.self, forKey: .authorizationURL)
            ?? container.decodeIfPresent(String.self, forKey: .authorizationUrl)
        {
            self.authorizationURL = authorizationURL
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.authorizationURL,
                .init(codingPath: decoder.codingPath, debugDescription: "Missing authorizationURL")
            )
        }
        expiresIn = try container.decode(Int.self, forKey: .expiresIn)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(flowId, forKey: .flowId)
        try container.encode(authorizationURL, forKey: .authorizationURL)
        try container.encode(expiresIn, forKey: .expiresIn)
    }
}

public struct OAuthExchangeRequest: Codable, Sendable, Equatable {
    public let flowId: UUID
    public let code: String
    public let state: String
    public let redirectURI: String

    public init(flowId: UUID, code: String, state: String, redirectURI: String) {
        self.flowId = flowId
        self.code = code
        self.state = state
        self.redirectURI = redirectURI
    }

    private enum CodingKeys: String, CodingKey {
        case flowId
        case code
        case state
        case redirectURI
        case redirectUri
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        flowId = try container.decode(UUID.self, forKey: .flowId)
        code = try container.decode(String.self, forKey: .code)
        state = try container.decode(String.self, forKey: .state)
        if let redirectURI = try container.decodeIfPresent(String.self, forKey: .redirectURI)
            ?? container.decodeIfPresent(String.self, forKey: .redirectUri)
        {
            self.redirectURI = redirectURI
            return
        }

        throw DecodingError.keyNotFound(
            CodingKeys.redirectURI,
            .init(codingPath: decoder.codingPath, debugDescription: "Missing redirectURI")
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(flowId, forKey: .flowId)
        try container.encode(code, forKey: .code)
        try container.encode(state, forKey: .state)
        try container.encode(redirectURI, forKey: .redirectURI)
    }
}
