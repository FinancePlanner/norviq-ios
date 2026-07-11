import Factory
import Foundation
import Observation
import StockPlanShared

@Observable @MainActor
final class SectorGainsViewModel {
  var response: SectorGainsResponse?
  var isLoading = false
  var errorMessage: String?

  private let statisticsService: any StatisticsServicing
  private var hasLoadedOnce = false

  init(statisticsService: any StatisticsServicing = Container.shared.statisticsService()) {
    self.statisticsService = statisticsService
  }

  func load(force: Bool = false) async {
    if !force, hasLoadedOnce { return }
    guard !isLoading else { return }

    isLoading = true
    errorMessage = nil

    do {
      response = try await statisticsService.fetchSectorGains()
      hasLoadedOnce = true
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }
}
