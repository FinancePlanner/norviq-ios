import Factory

extension Container {
  var pushNotificationsService: Factory<PushNotificationsServicing> {
    self { @MainActor [unowned self] in
      PushNotificationsService(
        environmentManager: self.appEnvironment(),
        authSessionManager: self.authSessionManager()
      )
    }
  }

  var pushNotificationsCoordinator: Factory<PushNotificationsCoordinator> {
    self { @MainActor [unowned self] in
      PushNotificationsCoordinator(
        service: self.pushNotificationsService(),
        sessionStore: self.authSessionStore()
      )
    }.singleton
  }
}
