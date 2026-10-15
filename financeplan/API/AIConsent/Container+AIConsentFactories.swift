import Factory
import Foundation

extension Container {
  var aiConsentClient: Factory<any AIConsentClientProtocol> {
    self { @MainActor [unowned self] in
      let env = self.appEnvironment()
      let auth = self.authSessionManager()
      return AIConsentHTTPClient(
        baseURL: env.current.apiBaseUrl,
        authTokenProvider: { try? await auth.validAccessToken() }
      )
    }
  }

  var aiConsentStore: Factory<AIConsentStore> {
    self { @MainActor [unowned self] in AIConsentStore(client: self.aiConsentClient()) }.singleton
  }
}
