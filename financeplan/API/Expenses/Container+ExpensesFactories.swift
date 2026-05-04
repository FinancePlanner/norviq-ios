import Factory
import Foundation

extension Container {
  var expensesHTTPClient: Factory<ExpensesHTTPClient> {
    self { @MainActor [unowned self] in
      let env = self.appEnvironment()
      let store = self.authSessionStore()
      return ExpensesHTTPClient(
        baseURL: env.current.apiBaseUrl,
        session: URLSession.shared,
        authTokenProvider: { await store.authToken }
      )
    }
  }

  var expensesService: Factory<ExpensesServicing> {
    self { @MainActor [unowned self] in
      ExpensesHTTPService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }
}
