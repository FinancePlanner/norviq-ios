import Factory

extension Container {
    /// One coordinator for the app: every screen's AI button talks to the one
    /// card mounted on `HomeScreen`.
    var quickAssistantCoordinator: Factory<QuickAssistantCoordinator> {
        self { @MainActor in
            QuickAssistantCoordinator(
                allowsAI: { Container.shared.aiConsentStore().allowsAI },
                presentConsent: { AIConsentPresenter.shared.present() }
            )
        }
        .singleton
    }
}
