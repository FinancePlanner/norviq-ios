import Foundation
import Observation
import StockPlanShared

/// Drives the Grow screen.
///
/// The projection is computed on device through `PlanningEngine`, the same code the
/// backend runs, so dragging the return slider redraws immediately instead of waiting on a
/// round trip. The network is only used to find out what the user already has.
@MainActor
@Observable
final class GrowViewModel {
  var initialAmount: Double = 10_000
  var monthlyContribution: Double = 400
  var years: Int = 20
  var annualReturnRate: Double = 0.07
  var annualInflationRate: Double = 0.02
  var annualContributionGrowthRate: Double = 0
  var showInTodaysMoney = false

  private(set) var result: ProjectionResult?
  private(set) var sensitivity: [SensitivityPoint] = []
  private(set) var currency = "EUR"
  private(set) var prefilledFromPortfolio = false
  private(set) var isLoading = false
  private(set) var errorMessage: String?

  @ObservationIgnored private let service: any PlanningServicing

  init(service: any PlanningServicing) {
    self.service = service
    recompute()
  }

  var assumptions: ProjectionAssumptions {
    ProjectionAssumptions(
      initialAmount: initialAmount,
      monthlyContribution: monthlyContribution,
      annualReturnRate: annualReturnRate,
      annualContributionGrowthRate: annualContributionGrowthRate,
      annualInflationRate: annualInflationRate,
      years: years
    )
  }

  /// The headline. Follows the toggle so the big number always matches its label.
  var headlineValue: Double {
    guard let result else { return 0 }
    return showInTodaysMoney ? result.endingValueReal : result.endingValueNominal
  }

  var secondaryValue: Double {
    guard let result else { return 0 }
    return showInTodaysMoney ? result.endingValueNominal : result.endingValueReal
  }

  var growthShare: Double {
    guard let result, result.endingValueNominal > 0 else { return 0 }
    return result.totalGrowth / result.endingValueNominal
  }

  /// Recomputes locally. Cheap enough to call on every slider tick - at most 1200
  /// iterations - so there is no debounce to get wrong.
  func recompute() {
    do {
      result = try PlanningEngine.project(assumptions)
      sensitivity = try PlanningEngine.sensitivity(assumptions)
      errorMessage = nil
    } catch {
      result = nil
      sensitivity = []
      errorMessage = String(localized: "Those assumptions do not describe a plan that can be projected.")
    }
  }

  /// Opens the screen on the user's real portfolio where there is one. A failure here
  /// leaves the defaults in place rather than blocking the calculator.
  func loadPrefill() async {
    isLoading = true
    defer { isLoading = false }

    do {
      let prefill = try await service.prefill()
      currency = prefill.currency
      if prefill.hasPortfolio, prefill.portfolioValue > 0 {
        initialAmount = prefill.portfolioValue.rounded()
        prefilledFromPortfolio = true
      }
      recompute()
    } catch {
      // Deliberately quiet: pre-fill is a convenience, not the feature.
    }
  }
}
