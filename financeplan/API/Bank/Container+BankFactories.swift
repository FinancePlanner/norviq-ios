import Factory

extension Container {
  var bankService: Factory<BankServicing> {
    self { @MainActor [unowned self] in
      BankService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }
}
