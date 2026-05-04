import Factory
import Foundation

extension Container {
  var marketDataHTTPClient: Factory<MarketDataHTTPClient> {
    self { @MainActor [unowned self] in
      let env = self.appEnvironment()
      let store = self.authSessionStore()
      return MarketDataHTTPClient(
        baseURL: env.current.apiBaseUrl,
        session: URLSession.shared,
        authTokenProvider: { await store.authToken }
      )
    }
  }

  var marketDataService: Factory<MarketDataServicing> {
    self { @MainActor [unowned self] in
      MarketDataHTTPService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }

  var cryptoService: Factory<CryptoServicing> {
    self { @MainActor [unowned self] in
      CryptoHTTPService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }
}
