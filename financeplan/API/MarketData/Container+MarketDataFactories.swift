import Factory
import Foundation

extension Container {
  var marketDataHTTPClient: Factory<MarketDataHTTPClient> {
    self { [unowned self] in
      let env = self.appEnvironment()
      let store = self.authSessionStore()
      return MarketDataHTTPClient(
        baseURL: env.current.apiBaseUrl,
        session: URLSession.shared,
        authTokenProvider: { store.authToken }
      )
    }
  }

  var marketDataService: Factory<MarketDataServicing> {
    self { [unowned self] in
      MarketDataHTTPService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }
}
