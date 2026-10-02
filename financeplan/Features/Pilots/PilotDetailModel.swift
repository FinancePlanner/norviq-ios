import Factory
import Foundation
import Observation
import StockPlanShared

@MainActor
@Observable
final class PilotDetailModel {
  let slug: String
  private(set) var detail: PilotDetail?
  private(set) var isLoading = false
  var errorMessage: String?

  private let service: any PilotsServicing

  init(slug: String, service: any PilotsServicing = Container.shared.pilotsService()) {
    self.slug = slug
    self.service = service
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      detail = try await service.pilot(slug: slug)
      errorMessage = nil
    } catch is CancellationError {
      return
    } catch {
      errorMessage = PilotsStore.isFeatureOff(error)
        ? String(localized: "This pilot isn't available right now.")
        : error.localizedDescription
    }
  }
}
