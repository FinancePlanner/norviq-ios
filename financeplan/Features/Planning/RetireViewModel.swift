import Foundation
import Observation
import StockPlanShared

/// Drives the Retire screen.
///
/// The need, the gap and the lever are deterministic and computed on device. The readiness
/// probability is a Monte Carlo run and comes from the server, so the screen shows the
/// answer immediately and fills the probability in when it arrives.
@MainActor
@Observable
final class RetireViewModel {
  var currentAge: Int = 40
  var retirementAge: Int = 60
  var longevityAge: Int = 90
  var monthlyCostOfLife: Double = 2_800
  var monthlyHousing: Double = 0
  var housingEndsAtAge: Int?
  var monthlyOtherIncome: Double = 0
  var annualInflationRate: Double = 0.02
  var withdrawalRate: Double = 0.04
  var annualReturnRate: Double = 0.07
  var investedToday: Double = 10_000
  var monthlyContribution: Double = 400

  private(set) var need: RetirementNeed?
  private(set) var lever: PlanLever?
  private(set) var projection: ProjectionResult?
  private(set) var readinessProbability: Double?
  private(set) var assumptionNotes: [String] = []
  private(set) var currency = "EUR"
  private(set) var hasBudget = true
  private(set) var isLoading = false
  private(set) var isCheckingProbability = false
  private(set) var errorMessage: String?

  @ObservationIgnored private let service: any PlanningServicing

  init(service: any PlanningServicing) {
    self.service = service
    recompute()
  }

  var needInput: RetirementNeedInput {
    RetirementNeedInput(
      currentAge: currentAge,
      retirementAge: retirementAge,
      longevityAge: longevityAge,
      monthlyCostOfLifeToday: monthlyCostOfLife,
      monthlyHousingToday: monthlyHousing,
      housingEndsAtAge: housingEndsAtAge,
      monthlyOtherIncomeAtRetirement: monthlyOtherIncome,
      annualInflationRate: annualInflationRate,
      withdrawalRate: withdrawalRate,
      expectedAnnualReturn: annualReturnRate
    )
  }

  var planAssumptions: ProjectionAssumptions {
    ProjectionAssumptions(
      initialAmount: investedToday,
      monthlyContribution: monthlyContribution,
      annualReturnRate: annualReturnRate,
      annualInflationRate: annualInflationRate,
      years: max(0, retirementAge - currentAge)
    )
  }

  var projectedAtRetirement: Double { projection?.endingValueNominal ?? 0 }

  var isOnTrack: Bool { lever?.isOnTrack ?? false }

  var runsOutOfMoney: Bool { need?.shortfallAge != nil }

  /// Red, amber, green. Amber is the case worth keeping: the S/w headline is missed while
  /// the money still lasts the whole plan, which is what happens when housing stops or a
  /// pension covers part of the cost. Calling that failure would be wrong.
  enum Verdict {
    case onTrack
    case shortButLasts
    case runsOut
  }

  var verdict: Verdict {
    if isOnTrack { return .onTrack }
    return runsOutOfMoney ? .runsOut : .shortButLasts
  }

  func recompute() {
    do {
      let projected = try PlanningEngine.project(planAssumptions)
      projection = projected
      need = try PlanningEngine.retirementNeed(needInput, projectedPortfolioAtRetirement: projected.endingValueNominal)
      lever = try PlanningEngine.lever(need: needInput, plan: planAssumptions)
      errorMessage = nil
    } catch {
      projection = nil
      need = nil
      lever = nil
      errorMessage = String(localized: "Those ages and figures do not describe a plan that can be checked.")
    }
    // The probability belongs to the inputs that produced it.
    readinessProbability = nil
  }

  func loadPrefill() async {
    isLoading = true
    defer { isLoading = false }

    do {
      let prefill = try await service.prefill()
      currency = prefill.currency
      hasBudget = prefill.hasBudget
      if let cost = prefill.monthlyCostOfLife, cost > 0 {
        monthlyCostOfLife = cost.rounded()
      }
      if let housing = prefill.monthlyHousing, housing > 0 {
        monthlyHousing = min(housing.rounded(), monthlyCostOfLife)
      }
      if prefill.hasPortfolio, prefill.portfolioValue > 0 {
        investedToday = prefill.portfolioValue.rounded()
      }
      if let age = prefill.suggestedRetirementAge, age > currentAge {
        retirementAge = age
      }
      recompute()
    } catch {
      // Pre-fill is a convenience; the calculator still works on its defaults.
    }
  }

  /// Asks the server for the Monte Carlo probability. Kept separate from `recompute` so a
  /// slider drag never fires thousands of simulated paths.
  func checkProbability() async {
    isCheckingProbability = true
    defer { isCheckingProbability = false }

    do {
      let response = try await service.retirement(
        RetirementPlanningRequest(need: needInput, plan: planAssumptions)
      )
      readinessProbability = response.readinessProbability
      assumptionNotes = response.assumptionNotes
    } catch {
      errorMessage = String(localized: "Could not work out the odds just now. The figures above still stand.")
    }
  }
}
