import Factory
import Foundation

extension Container {
  var spreadsheetImportHTTPClient: Factory<SpreadsheetImportHTTPClient> {
    self { @MainActor [unowned self] in
      let env = self.appEnvironment()
      let store = self.authSessionStore()
      return SpreadsheetImportHTTPClient(
        baseURL: env.current.apiBaseUrl,
        session: URLSession.shared,
        authTokenProvider: { await store.authToken }
      )
    }
  }
}
