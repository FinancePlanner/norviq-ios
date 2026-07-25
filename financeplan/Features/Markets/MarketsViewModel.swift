import Factory
import Foundation
import Observation

@MainActor
@Observable
final class MarketsViewModel {
  var overview: MarketOverviewResponse?
  var isLoading = false
  var errorMessage: String?

  private let marketDataService: any MarketDataServicing

  init(marketDataService: any MarketDataServicing = Container.shared.marketDataService()) {
    self.marketDataService = marketDataService
  }

  func load() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      overview = try await marketDataService.fetchMarketOverview()
    } catch {
      if overview == nil {
        errorMessage = error.localizedDescription
      }
    }
  }
}
