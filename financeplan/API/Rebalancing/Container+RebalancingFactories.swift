import Factory

extension Container {
  var rebalancingService: Factory<any RebalancingServicing> {
    self { @MainActor in
      RebalancingService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }
}
