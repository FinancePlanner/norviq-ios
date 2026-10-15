import Factory
import Foundation

extension Container {
  var marketBriefService: Factory<any MarketBriefServicing> {
    self { @MainActor in
      DefaultMarketBriefService(environmentManager: self.appEnvironment())
    }
  }

  /// Shared so the latest brief per language outlives the card, which is
  /// rebuilt whenever the root view's language or environment changes.
  var marketBriefCache: Factory<any MarketBriefCaching> {
    self { @MainActor in MarketBriefCache() }.singleton
  }

  /// Carries a push or link to the dashboard card.
  var marketBriefRouter: Factory<MarketBriefRouter> {
    self { @MainActor in MarketBriefRouter() }.singleton
  }

  var marketBriefAlertsStore: Factory<MarketBriefAlertsStore> {
    self { @MainActor in MarketBriefAlertsStore() }.singleton
  }
}
