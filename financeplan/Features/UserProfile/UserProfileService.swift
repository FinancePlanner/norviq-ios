//
//  UserProfileStub.swift
//  financeplan
//
//  Created by Fernando Correia on 05.03.26.
//

import Factory
import Foundation
import StockPlanShared

public protocol UserProfileServiceProtocol: Sendable {
    func fetchProfile() async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile
    func updateUsername(_ username: String) async throws -> UserProfile
    func updateEmail(_ email: String, currentPassword: String) async throws -> UserProfile
    func updatePassword(current: String, new: String) async throws
    func deleteAccount() async throws
}

final class UserProfileHTTPService: UserProfileServiceProtocol, @unchecked Sendable {
    private let environmentManager: AppEnvironmentManager
    private let session: UserProfileURLSessionProtocol
    private let authSessionManager: AuthSessionManaging

    init(
        environmentManager: AppEnvironmentManager,
        session: UserProfileURLSessionProtocol = URLSession.shared,
        authSessionManager: AuthSessionManaging
    ) {
        self.environmentManager = environmentManager
        self.session = session
        self.authSessionManager = authSessionManager
    }

    func fetchProfile() async throws -> UserProfile {
        let response: GetUserProfileResponse = try await performAuthenticated { client in
            try await client.fetchProfile(GetUserProfileRequest(id: nil))
        }
        return response.userProfile
    }

    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        let response: UpdateUserProfileResponse = try await performAuthenticated { client in
            try await client.updateProfile(UpdateUserProfileRequest(userProfile: profile))
        }
        return response.userProfile
    }

    func updateUsername(_ username: String) async throws -> UserProfile {
        let response: UpdateUserProfileResponse = try await performAuthenticated { client in
            try await client.updateUsername(UpdateUsernameRequest(username: username))
        }
        return response.userProfile
    }

    func updateEmail(_ email: String, currentPassword: String) async throws -> UserProfile {
        do {
            // A wrong password is a 401 on older backends; it must not be mistaken
            // for an expired session (refresh, retry, then sign the user out).
            let response: UpdateUserProfileResponse = try await performAuthenticated(
                refreshesOn: { !CurrentPasswordError.isLegacyWrongPassword($0) }
            ) { client in
                // Read inside the operation: a refresh above may have rotated it.
                let refreshToken = await Container.shared.authSessionStore().refreshToken
                return try await client.updateEmail(ChangeEmailRequest(
                    email: email,
                    currentPassword: currentPassword,
                    refreshToken: refreshToken
                ))
            }
            return response.userProfile
        } catch let error as UserProfileHTTPClient.Error {
            throw EmailChangeError(error) ?? error
        }
    }

    func updatePassword(current: String, new: String) async throws {
        do {
            _ = try await performAuthenticated(
                refreshesOn: { !CurrentPasswordError.isLegacyWrongPassword($0) }
            ) { client in
                // Read inside the operation: a refresh above may have rotated it.
                let refreshToken = await Container.shared.authSessionStore().refreshToken
                return try await client.updatePassword(
                    UpdatePasswordRequest(currentPassword: current, newPassword: new),
                    refreshToken: refreshToken
                )
            }
        } catch let error as UserProfileHTTPClient.Error {
            throw PasswordChangeError(error) ?? error
        }
    }

    func deleteAccount() async throws {
        _ = try await performAuthenticated { client in
            try await client.deleteProfile(DeleteUserProfileRequest(id: nil))
        }
    }

    private func makeClient(forceRefresh: Bool = false) async throws -> UserProfileHTTPClient {
        let token = try await resolvedAccessToken(forceRefresh: forceRefresh)
        return UserProfileHTTPClient(
            baseURL: environmentManager.current.apiBaseUrl,
            session: session,
            authTokenProvider: { token }
        )
    }

    private func performAuthenticated<T: Sendable>(
        refreshesOn shouldRefresh: (UserProfileHTTPClient.Error) -> Bool = { _ in true },
        _ operation: (UserProfileHTTPClient) async throws -> T
    ) async throws -> T {
        do {
            let client = try await makeClient()
            return try await operation(client)
        } catch let error as UserProfileHTTPClient.Error where error.isUnauthorized && shouldRefresh(error) {
            do {
                let client = try await makeClient(forceRefresh: true)
                return try await operation(client)
            } catch let retryError as UserProfileHTTPClient.Error
                where retryError.isUnauthorized && shouldRefresh(retryError) {
                await authSessionManager.invalidateSession()
                throw retryError
            } catch {
                throw error
            }
        }
    }

    private func resolvedAccessToken(forceRefresh: Bool) async throws -> String {
        let token = forceRefresh
            ? try await authSessionManager.refreshAccessToken()
            : try await authSessionManager.validAccessToken()

        guard let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthSessionError.notAuthenticated
        }

        return token
    }
}

public final class UserProfileServiceStub: UserProfileServiceProtocol, @unchecked Sendable {
    public init() {}

    public func fetchProfile() async throws -> UserProfile {
        try await Task.sleep(nanoseconds: 300_000_000)
        return UserProfile(
            id: "preview-user",
            email: "",
            bio: "",
            username: ""
        )
    }

    public func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        // Simulate a network delay and echo back the profile
        try await Task.sleep(nanoseconds: 200_000_000)
        return profile
    }

    public func updateUsername(_ username: String) async throws -> UserProfile {
        try await Task.sleep(nanoseconds: 200_000_000)
        return UserProfile(id: "preview-user", email: "", username: username)
    }

    public func updateEmail(_ email: String, currentPassword _: String) async throws -> UserProfile {
        try await Task.sleep(nanoseconds: 200_000_000)
        return UserProfile(id: "preview-user", email: email, username: "")
    }

    public func updatePassword(current: String, new: String) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
    }

    public func deleteAccount() async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
    }
}

/// Recognises the "current password" refusals shared by the email and
/// password routes.
nonisolated enum CurrentPasswordError {
    case required
    case incorrect

    init?(_ error: UserProfileHTTPClient.Error) {
        switch error {
        case .api("CURRENT_PASSWORD_REQUIRED"):
            self = .required
        case .api("INVALID_CURRENT_PASSWORD"):
            self = .incorrect
        case let error where Self.isLegacyWrongPassword(error):
            self = .incorrect
        default:
            return nil
        }
    }

    /// Older backends answered a wrong current password with 401 and a
    /// password reason — unlike an expired access token, which must refresh.
    static func isLegacyWrongPassword(_ error: UserProfileHTTPClient.Error) -> Bool {
        if case let .unauthorized(message?) = error {
            return message.localizedCaseInsensitiveContains("password")
        }
        return false
    }
}

/// The email-change refusals the user can act on.
nonisolated enum EmailChangeError: LocalizedError, Equatable {
    case currentPasswordRequired
    case wrongPassword
    /// Apple/Google-only account: there is no password to confirm with.
    case reauthRequired
    /// Also a 409, told apart from `reauthRequired` by its reason.
    case emailAlreadyRegistered

    init?(_ error: UserProfileHTTPClient.Error) {
        switch (error, CurrentPasswordError(error)) {
        case (_, .required?):
            self = .currentPasswordRequired
        case (_, .incorrect?):
            self = .wrongPassword
        case (.api("REAUTH_REQUIRED"), nil):
            self = .reauthRequired
        case let (.api(reason), nil) where reason.localizedCaseInsensitiveContains("already registered"):
            self = .emailAlreadyRegistered
        default:
            return nil
        }
    }

    var errorDescription: String? {
        switch self {
        case .currentPasswordRequired:
            return String(localized: "Enter your current password to change your email.")
        case .wrongPassword:
            return String(localized: "Your current password is incorrect.")
        case .reauthRequired:
            return String(localized: "Your account uses Apple/Google sign-in. Contact fernando@facorreia.com to change your email.")
        case .emailAlreadyRegistered:
            return String(localized: "That email is already used by another account.")
        }
    }
}

/// The password-change refusals the user can act on.
nonisolated enum PasswordChangeError: LocalizedError, Equatable {
    case currentPasswordRequired
    case wrongPassword

    init?(_ error: UserProfileHTTPClient.Error) {
        switch CurrentPasswordError(error) {
        case .required?: self = .currentPasswordRequired
        case .incorrect?: self = .wrongPassword
        case nil: return nil
        }
    }

    var errorDescription: String? {
        switch self {
        case .currentPasswordRequired:
            return String(localized: "Enter your current password to change your password.")
        case .wrongPassword:
            return String(localized: "Your current password is incorrect.")
        }
    }
}
