import Factory

extension Container {
    var persistentAssistantService: Factory<any PersistentAssistantServicing> {
        self { @MainActor in
            DefaultPersistentAssistantService(
                environmentManager: self.appEnvironment(),
                authSessionManager: self.authSessionManager()
            )
        }
    }
}
