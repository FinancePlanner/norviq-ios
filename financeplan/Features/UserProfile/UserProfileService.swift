//
//  UserProfileStub.swift
//  financeplan
//
//  Created by Fernando Correia on 05.03.26.
//

import Foundation
import StockPlanShared

public protocol UserProfileServiceProtocol {
    func fetchProfile() async throws -> UserProfile
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile
    func updateUsername(_ username: String) async throws -> UserProfile
    func updateEmail(_ email: String) async throws -> UserProfile
    func updatePassword(current: String, new: String) async throws
}

final class UserProfileHTTPService: UserProfileServiceProtocol {
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

    func updateEmail(_ email: String) async throws -> UserProfile {
        let response: UpdateUserProfileResponse = try await performAuthenticated { client in
            try await client.updateEmail(UpdateEmailRequest(email: email))
        }
        return response.userProfile
    }

    func updatePassword(current: String, new: String) async throws {
        _ = try await performAuthenticated { client in
            try await client.updatePassword(UpdatePasswordRequest(currentPassword: current, newPassword: new))
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
        _ operation: (UserProfileHTTPClient) async throws -> T
    ) async throws -> T {
        do {
            let client = try await makeClient()
            return try await operation(client)
        } catch let error as UserProfileHTTPClient.Error where error.isUnauthorized {
            do {
                let client = try await makeClient(forceRefresh: true)
                return try await operation(client)
            } catch let retryError as UserProfileHTTPClient.Error where retryError.isUnauthorized {
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

public final class UserProfileServiceStub: UserProfileServiceProtocol {
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

    public func updateEmail(_ email: String) async throws -> UserProfile {
        try await Task.sleep(nanoseconds: 200_000_000)
        return UserProfile(id: "preview-user", email: email, username: "")
    }

    public func updatePassword(current: String, new: String) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
    }
}
