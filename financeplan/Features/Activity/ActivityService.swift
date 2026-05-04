import Foundation
import StockPlanShared
import Factory

protocol ActivityServicing: Sendable {
    func fetchActivities(limit: Int?) async throws -> [UserActivityResponse]
}

struct ActivityHTTPService: ActivityServicing, @unchecked Sendable {
    private let environmentManager: AppEnvironmentManager
    private let authSessionManager: AuthSessionManaging

    init(
        environmentManager: AppEnvironmentManager,
        authSessionManager: AuthSessionManaging
    ) {
        self.environmentManager = environmentManager
        self.authSessionManager = authSessionManager
    }

    func fetchActivities(limit: Int?) async throws -> [UserActivityResponse] {
        try await performAuthenticated { client in
            try await client.fetchActivities(limit: limit)
        }
    }

    private func client() async throws -> ActivityHTTPClient {
        let token = try await authSessionManager.validAccessToken()
        return ActivityHTTPClient(
            baseURL: environmentManager.current.apiBaseUrl,
            authTokenProvider: { token }
        )
    }

    private func performAuthenticated<T: Sendable>(
        _ action: @escaping (ActivityHTTPClient) async throws -> T
    ) async throws -> T {
        guard let _ = try await authSessionManager.validAccessToken() else {
            throw AuthSessionError.notAuthenticated
        }

        let client = try await client()
        return try await action(client)
    }
}

extension Container {
    var activityService: Factory<ActivityServicing> {
        self { @MainActor in
            ActivityHTTPService(
                environmentManager: self.appEnvironment(),
                authSessionManager: self.authSessionManager()
            )
        }.singleton
    }
}
