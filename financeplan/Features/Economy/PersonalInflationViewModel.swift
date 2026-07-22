import Factory
import Foundation
import Observation
import StockPlanShared

@MainActor
@Observable
final class PersonalInflationViewModel {
  typealias Loader = @MainActor @Sendable (String, Int) async throws -> PersonalInflationResponse

  var response: PersonalInflationResponse?
  var isLoading = false
  var errorMessage: String?

  private let loader: Loader

  init(loader: @escaping Loader = { country, months in
    try await Container.shared.macroService().getPersonalInflation(country: country, months: months)
  }) {
    self.loader = loader
  }

  func load(country: String, months: Int) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      response = try await loader(country, months)
    } catch {
      response = nil
      errorMessage = error.localizedDescription
    }
  }

  static func comparisonText(for response: PersonalInflationResponse) -> String? {
    guard let difference = response.difference else { return nil }
    if abs(difference) < 0.05 { return String(localized: "About the same as the official rate") }
    let magnitude = abs(difference).formatted(.number.precision(.fractionLength(2)))
    return difference > 0
      ? String(localized: "\(magnitude) percentage points above official inflation")
      : String(localized: "\(magnitude) percentage points below official inflation")
  }
}
