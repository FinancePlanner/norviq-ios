import Foundation

public enum PushAuthorizationStatus: String, Codable, Sendable, Equatable, CaseIterable {
    case notDetermined
    case denied
    case authorized
    case provisional
}

public enum PushAPNSEnvironment: String, Codable, Sendable, Equatable, CaseIterable {
    case development
    case production
}

public enum PushPlatform: String, Codable, Sendable, Equatable, CaseIterable {
    case ios
}

public struct PushDeviceRegistrationRequest: Codable, Sendable, Equatable {
    public let deviceToken: String
    public let platform: PushPlatform
    public let apnsEnvironment: PushAPNSEnvironment
    public let authorizationStatus: PushAuthorizationStatus
    public let capabilities: [String]?

    public init(
        deviceToken: String,
        platform: PushPlatform = .ios,
        apnsEnvironment: PushAPNSEnvironment,
        authorizationStatus: PushAuthorizationStatus,
        capabilities: [String]? = nil
    ) {
        self.deviceToken = deviceToken
        self.platform = platform
        self.apnsEnvironment = apnsEnvironment
        self.authorizationStatus = authorizationStatus
        self.capabilities = capabilities
    }
}

public struct PushDeviceRegistrationResponse: Codable, Sendable, Equatable {
    public let id: String
    public let deviceToken: String
    public let platform: PushPlatform
    public let apnsEnvironment: PushAPNSEnvironment
    public let authorizationStatus: PushAuthorizationStatus
    public let isActive: Bool
    public let lastSeenAt: String
    public let capabilities: [String]?

    public init(
        id: String,
        deviceToken: String,
        platform: PushPlatform,
        apnsEnvironment: PushAPNSEnvironment,
        authorizationStatus: PushAuthorizationStatus,
        isActive: Bool,
        lastSeenAt: String,
        capabilities: [String]? = nil
    ) {
        self.id = id
        self.deviceToken = deviceToken
        self.platform = platform
        self.apnsEnvironment = apnsEnvironment
        self.authorizationStatus = authorizationStatus
        self.isActive = isActive
        self.lastSeenAt = lastSeenAt
        self.capabilities = capabilities
    }
}

public struct PushDeviceDeactivateRequest: Codable, Sendable, Equatable {
    public let deviceToken: String

    public init(deviceToken: String) {
        self.deviceToken = deviceToken
    }
}

public struct EarningsNotificationPreferencesResponse: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let leadDays: [Int]
    public let scope: String

    public init(enabled: Bool, leadDays: [Int] = [7, 1], scope: String = "portfolio_and_watchlist") {
        self.enabled = enabled
        self.leadDays = leadDays
        self.scope = scope
    }
}

public struct UpdateEarningsNotificationPreferencesRequest: Codable, Sendable, Equatable {
    public let enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }
}
