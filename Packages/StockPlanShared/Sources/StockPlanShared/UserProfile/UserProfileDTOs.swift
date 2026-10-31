import Foundation

public struct UserProfile: Codable, Sendable, Equatable {
    public let id: String
    public var email: String
    public var bio: String?
    public var avatarURL: URL?
    public var bannerAvatarURL: URL?
    public var username: String?

    public init(
        id: String,
        email: String,
        bio: String? = nil,
        avatarURL: URL? = nil,
        bannerAvatarURL: URL? = nil,
        username: String? = nil
    ) {
        self.id = id
        self.email = email
        self.bio = bio
        self.avatarURL = avatarURL
        self.bannerAvatarURL = bannerAvatarURL
        self.username = username
    }
}

public struct GetUserProfileRequest: Codable, Sendable, Equatable {
    public let id: String?

    public init(id: String? = nil) {
        self.id = id
    }
}

public struct GetUserProfileResponse: Codable, Sendable, Equatable {
    public let userProfile: UserProfile

    public init(userProfile: UserProfile) {
        self.userProfile = userProfile
    }
}

public struct UpdateUserProfileRequest: Codable, Sendable, Equatable {
    public let userProfile: UserProfile

    public init(userProfile: UserProfile) {
        self.userProfile = userProfile
    }
}

public struct UpdateUserProfileResponse: Codable, Sendable, Equatable {
    public let userProfile: UserProfile

    public init(userProfile: UserProfile) {
        self.userProfile = userProfile
    }
}

public struct DeleteUserProfileRequest: Codable, Sendable, Equatable {
    public let id: String?

    public init(id: String? = nil) {
        self.id = id
    }
}

public struct DeleteUserProfileResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let message: String?

    public init(success: Bool = true, message: String? = nil) {
        self.success = success
        self.message = message
    }
}

public struct FeedbackRequest: Codable, Sendable, Equatable {
    public let topic: String
    public let message: String

    public init(topic: String, message: String) {
        self.topic = topic
        self.message = message
    }
}

public struct FeedbackResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let message: String?

    public init(success: Bool = true, message: String? = nil) {
        self.success = success
        self.message = message
    }
}

public struct UpdateUsernameRequest: Codable, Sendable, Equatable {
    public let username: String

    public init(username: String) {
        self.username = username
    }
}

public struct UpdateEmailRequest: Codable, Sendable, Equatable {
    public let email: String

    public init(email: String) {
        self.email = email
    }
}

public struct UpdatePasswordRequest: Codable, Sendable, Equatable {
    public let currentPassword: String
    public let newPassword: String

    public init(currentPassword: String, newPassword: String) {
        self.currentPassword = currentPassword
        self.newPassword = newPassword
    }
}
