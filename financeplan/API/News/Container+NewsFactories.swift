import Factory
import Foundation

extension Container {
    var newsHTTPClient: Factory<NewsHTTPClient> {
        self { @MainActor [unowned self] in
            let env = self.appEnvironment()
            let store = self.authSessionStore()
            return NewsHTTPClient(
                baseURL: env.current.apiBaseUrl,
                session: .shared,
                authTokenProvider: { store.authToken }
            )
        }
    }

    var newsService: Factory<NewsServicing> {
        self { @MainActor [unowned self] in
            NewsHTTPService(
                environmentManager: self.appEnvironment(),
                authSessionManager: self.authSessionManager()
            )
        }
    }
}