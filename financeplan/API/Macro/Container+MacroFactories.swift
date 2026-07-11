import Factory
import Foundation

extension Container {
  var macroHTTPClient: Factory<MacroHTTPClient> {
    self { @MainActor [unowned self] in
      let env = self.appEnvironment()
      let store = self.authSessionStore()
      return MacroHTTPClient(
        baseURL: env.current.apiBaseUrl,
        session: URLSession.shared,
        authTokenProvider: { await store.authToken }
      )
    }
  }

  // Simple service wrapper (expand later with caching / error mapping)
  var macroService: Factory<MacroServicing> {
    self { @MainActor [unowned self] in
      MacroHTTPService(httpClient: self.macroHTTPClient())
    }
  }
}
