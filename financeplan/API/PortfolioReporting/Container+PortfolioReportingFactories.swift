import Factory

extension Container {
  var portfolioReportingService: Factory<any PortfolioReportingServicing> {
    self { @MainActor in
      PortfolioReportingService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }
}
