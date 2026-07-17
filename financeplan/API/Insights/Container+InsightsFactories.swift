import Factory
import Foundation

extension Container {
    var insightsHTTPClient: Factory<InsightsHTTPClient> {
        self { @MainActor [unowned self] in
            let env = self.appEnvironment()
            let store = self.authSessionStore()
            return InsightsHTTPClient(
                baseURL: env.current.apiBaseUrl,
                session: URLSession.shared,
                authTokenProvider: { await store.authToken }
            )
        }
    }
}
