import Factory

extension Container {
  var goalPlanningService: Factory<any GoalPlanningServicing> {
    self { @MainActor in
      GoalPlanningService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }
}
