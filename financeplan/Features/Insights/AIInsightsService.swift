import Foundation
import StockPlanShared

@MainActor
protocol AIInsightsServicing: Sendable {
    func generate(kind: AIInsightKind) async throws -> AIInsightCardResponse
}

final class AIInsightsHTTPService: AIInsightsServicing {
    private let environmentManager: AppEnvironmentManager
    private let session: MarketDataURLSessionProtocol
    private let authSessionManager: AuthSessionManaging

    init(
        environmentManager: AppEnvironmentManager,
        session: MarketDataURLSessionProtocol = URLSession.shared,
        authSessionManager: AuthSessionManaging
    ) {
        self.environmentManager = environmentManager
        self.session = session
        self.authSessionManager = authSessionManager
    }

    func generate(kind: AIInsightKind) async throws -> AIInsightCardResponse {
        try await performAuthenticated { client in
            try await client.generate(kind: kind)
        }
    }

    private func makeClient(forceRefresh: Bool = false) async throws -> AIInsightsHTTPClient {
        let token = try await resolvedAccessToken(forceRefresh: forceRefresh)
        return AIInsightsHTTPClient(
            baseURL: environmentManager.current.apiBaseUrl,
            session: session,
            authTokenProvider: { token }
        )
    }

    private func performAuthenticated<T: Sendable>(
        _ operation: (AIInsightsHTTPClient) async throws -> T
    ) async throws -> T {
        do {
            let client = try await makeClient()
            return try await operation(client)
        } catch let error as AIInsightsHTTPClient.Error where error.isUnauthorized {
            do {
                let client = try await makeClient(forceRefresh: true)
                return try await operation(client)
            } catch let retryError as AIInsightsHTTPClient.Error where retryError.isUnauthorized {
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
