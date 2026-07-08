import Foundation
import Observation
import StockPlanShared
import Factory

@MainActor
@Observable
final class MacroViewModel {
  var snapshot: InflationSnapshotResponse?
  var isLoading = false
  var errorMessage: String?

  private let macroService: any MacroServicing = Container.shared.macroService()

  func load(country: String? = nil) async {
    isLoading = true
    errorMessage = nil
    do {
      let data = try await macroService.getCurrentInflation(country: country)
      self.snapshot = data
    } catch {
      self.errorMessage = error.localizedDescription
    }
    isLoading = false
  }

  func topMoversForFocus(country: String? = nil) async -> [TopMoverDTO] {
    do {
      return try await macroService.getTopMovers(country: country, focus: "utilities,food,shelter")
    } catch {
      return snapshot?.topMovers ?? []
    }
  }
}
