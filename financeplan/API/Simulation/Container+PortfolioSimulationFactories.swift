import Factory

extension Container {
  var portfolioSimulationService: Factory<any PortfolioSimulationServicing> {
    self { @MainActor in
      PortfolioSimulationService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }
}
