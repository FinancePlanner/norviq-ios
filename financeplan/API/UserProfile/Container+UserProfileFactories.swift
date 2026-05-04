import Foundation
import Factory

extension Container {
  var userProfileHTTPClient: Factory<UserProfileHTTPClient> {
    self { @MainActor [unowned self] in
      let env = self.appEnvironment()
      let store = self.authSessionStore()
      return UserProfileHTTPClient(
        baseURL: env.current.apiBaseUrl,
        session: URLSession.shared,
        authTokenProvider: { await store.authToken }
      )
    }
  }

  var userProfileService: Factory<UserProfileServiceProtocol> {
    self { @MainActor [unowned self] in
      UserProfileHTTPService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }
}
