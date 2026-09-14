import Factory

extension Container {
  var planningService: Factory<any PlanningServicing> {
    self { @MainActor in
      PlanningService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }
}
