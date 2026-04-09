import Factory

extension Container {
  var brokerService: Factory<BrokerServicing> {
    self { @MainActor [unowned self] in
      BrokerService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }
}
