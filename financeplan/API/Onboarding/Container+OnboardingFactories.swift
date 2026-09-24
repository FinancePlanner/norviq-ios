import Factory
import Foundation

extension Container {
  var onboardingClient: Factory<any OnboardingClientProtocol> {
    self { @MainActor [unowned self] in
      let env = self.appEnvironment()
      let auth = self.authSessionManager()
      return OnboardingHTTPClient(
        baseURL: env.current.apiBaseUrl,
        authTokenProvider: { try? await auth.validAccessToken() }
      )
    }
  }

  var onboardingStateStore: Factory<OnboardingStateStore> {
    self { @MainActor [unowned self] in OnboardingStateStore(client: self.onboardingClient()) }.singleton
  }
}
