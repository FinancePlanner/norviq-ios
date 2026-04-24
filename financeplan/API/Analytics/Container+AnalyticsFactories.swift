import Factory

extension Container {
    var analytics: Factory<AnalyticsService> {
        Factory(self) { @MainActor in AnalyticsService() }.singleton
    }
}
