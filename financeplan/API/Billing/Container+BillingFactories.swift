import Factory
import Foundation

extension Container {
  var billingHTTPClient: Factory<BillingHTTPClient> {
    self { @MainActor [unowned self] in
      let env = self.appEnvironment()
      let store = self.authSessionStore()
      return BillingHTTPClient(
        baseURL: env.current.apiBaseUrl,
        session: URLSession.shared,
        authTokenProvider: { store.authToken }
      )
    }
  }

  var billingManager: Factory<BillingManager> {
    self { @MainActor [unowned self] in
      BillingManager(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager(),
        sessionStore: self.authSessionStore()
      )
    }.singleton
  }
}
