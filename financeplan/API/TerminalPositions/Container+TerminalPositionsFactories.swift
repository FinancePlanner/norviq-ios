import Factory

extension Container {
  var terminalPositionsService: Factory<any TerminalPositionsServicing> {
    self { @MainActor in
      TerminalPositionsService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }
}
