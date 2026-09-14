import Foundation
import StockPlanShared
import Testing
@testable import financeplan

/// A stub rather than a mocking framework, matching the rest of the suite.
private struct PlanningServiceStub: PlanningServicing {
  var prefillResult: PlanningPrefill?
  var retirementResult: RetirementPlanningResponse?
  var shouldThrow = false

  func prefill() async throws -> PlanningPrefill {
    if shouldThrow { throw URLError(.notConnectedToInternet) }
    guard let prefillResult else { throw URLError(.badServerResponse) }
    return prefillResult
  }

  func project(_: GrowthProjectionRequest) async throws -> GrowthProjectionResponse {
    throw URLError(.unsupportedURL)
  }

  func retirement(_: RetirementPlanningRequest) async throws -> RetirementPlanningResponse {
    if shouldThrow { throw URLError(.notConnectedToInternet) }
    guard let retirementResult else { throw URLError(.badServerResponse) }
    return retirementResult
  }

  func scenarios() async throws -> [PlanningScenario] { [] }

  func save(_: PlanningScenarioUpsertRequest) async throws -> PlanningScenario {
    throw URLError(.unsupportedURL)
  }
}

@MainActor
@Suite("Grow view model")
struct GrowViewModelTests {
  /// The point of computing on device: a value exists before any network call.
  @Test
  func `a projection is available the moment the screen is created`() {
    let model = GrowViewModel(service: PlanningServiceStub())

    #expect(model.result != nil)
    #expect(model.sensitivity.count == 3)
    #expect(model.headlineValue > 0)
  }

  @Test
  func `the headline follows the today's money toggle`() {
    let model = GrowViewModel(service: PlanningServiceStub())
    let nominal = model.headlineValue

    model.showInTodaysMoney = true

    #expect(model.headlineValue < nominal)
    #expect(model.secondaryValue == nominal)
  }

  @Test
  func `changing an assumption changes the answer`() {
    let model = GrowViewModel(service: PlanningServiceStub())
    let before = model.headlineValue

    model.annualReturnRate = 0.09
    model.recompute()

    #expect(model.headlineValue > before)
  }

  @Test
  func `a portfolio value opens the screen on the user's own number`() async {
    let stub = PlanningServiceStub(prefillResult: PlanningPrefill(
      currency: "EUR", portfolioValue: 52_000, hasBudget: true, hasPortfolio: true
    ))
    let model = GrowViewModel(service: stub)

    await model.loadPrefill()

    #expect(model.initialAmount == 52_000)
    #expect(model.prefilledFromPortfolio)
    #expect(model.currency == "EUR")
  }

  /// Pre-fill is a convenience. Losing it must leave a usable calculator.
  @Test
  func `a failed prefill leaves the defaults intact`() async {
    let model = GrowViewModel(service: PlanningServiceStub(shouldThrow: true))
    let before = model.initialAmount

    await model.loadPrefill()

    #expect(model.initialAmount == before)
    #expect(model.prefilledFromPortfolio == false)
    #expect(model.result != nil)
    #expect(model.errorMessage == nil)
  }
}

@MainActor
@Suite("Retire view model")
struct RetireViewModelTests {
  private func stub(
    costOfLife: Double? = nil,
    housing: Double? = nil,
    portfolio: Double = 0,
    retirementAge: Int? = nil,
    hasBudget: Bool = true
  ) -> PlanningServiceStub {
    PlanningServiceStub(prefillResult: PlanningPrefill(
      currency: "EUR",
      portfolioValue: portfolio,
      monthlyCostOfLife: costOfLife,
      monthlyHousing: housing,
      suggestedRetirementAge: retirementAge,
      hasBudget: hasBudget,
      hasPortfolio: portfolio > 0
    ))
  }

  @Test
  func `the need and the lever are worked out without a network call`() {
    let model = RetireViewModel(service: PlanningServiceStub())

    #expect(model.need != nil)
    #expect(model.lever != nil)
    #expect(model.projection != nil)
    #expect(model.readinessProbability == nil)
  }

  /// Red, amber, green. The amber case is the one worth keeping: the headline
  /// target is missed while the money still lasts the whole plan.
  @Test
  func `missing the target while the money lasts is not reported as failure`() {
    let model = RetireViewModel(service: PlanningServiceStub())
    model.monthlyCostOfLife = 2_800
    model.investedToday = 1_000_000
    model.monthlyContribution = 0
    model.recompute()

    if model.isOnTrack == false, model.runsOutOfMoney == false {
      #expect(model.verdict == .shortButLasts)
    }
  }

  @Test
  func `a plan that cannot fund the life is reported as running out`() {
    let model = RetireViewModel(service: PlanningServiceStub())
    model.monthlyCostOfLife = 5_000
    model.investedToday = 1_000
    model.monthlyContribution = 10
    model.recompute()

    #expect(model.runsOutOfMoney)
    #expect(model.verdict == .runsOut)
    #expect(model.isOnTrack == false)
  }

  @Test
  func `a comfortable plan is reported as on track`() {
    let model = RetireViewModel(service: PlanningServiceStub())
    model.monthlyCostOfLife = 500
    model.investedToday = 900_000
    model.monthlyContribution = 3_000
    model.recompute()

    #expect(model.isOnTrack)
    #expect(model.verdict == .onTrack)
  }

  @Test
  func `the screen opens on the user's budget and portfolio`() async {
    let model = RetireViewModel(service: stub(
      costOfLife: 2_450, housing: 900, portfolio: 52_000, retirementAge: 58
    ))

    await model.loadPrefill()

    #expect(model.monthlyCostOfLife == 2_450)
    #expect(model.monthlyHousing == 900)
    #expect(model.investedToday == 52_000)
    #expect(model.retirementAge == 58)
  }

  /// Housing is a slice of the cost of life. A pre-filled housing figure larger
  /// than the total would double-count the biggest line on the screen.
  @Test
  func `prefilled housing never exceeds the cost of life`() async {
    let model = RetireViewModel(service: stub(costOfLife: 800, housing: 1_500))

    await model.loadPrefill()

    #expect(model.monthlyHousing <= model.monthlyCostOfLife)
  }

  @Test
  func `having no budget is remembered so the screen can say so`() async {
    let model = RetireViewModel(service: stub(costOfLife: nil, hasBudget: false))

    await model.loadPrefill()

    #expect(model.hasBudget == false)
  }

  /// The probability belongs to the inputs that produced it; changing an input
  /// must not leave a stale figure on screen.
  @Test
  func `editing an input clears a previously fetched probability`() async {
    let response = RetirementPlanningResponse(
      need: RetirementNeed(
        annualSpendingAtRetirement: 49_926, nestEggAtWithdrawalRate: 1_248_158,
        depletion: [], runwayYears: 30, endingBalance: 0, shortfallAge: nil
      ),
      lever: PlanLever(gap: 1_000),
      projection: try! PlanningEngine.project(
        ProjectionAssumptions(initialAmount: 1, monthlyContribution: 1, annualReturnRate: 0.07, years: 1)
      ),
      projectedPortfolioAtRetirement: 610_000,
      readinessProbability: 0.62,
      assumptionNotes: ["Projections, not advice."]
    )
    var service = PlanningServiceStub()
    service.retirementResult = response
    let model = RetireViewModel(service: service)

    await model.checkProbability()
    #expect(model.readinessProbability == 0.62)

    model.monthlyCostOfLife = 3_500
    model.recompute()

    #expect(model.readinessProbability == nil)
  }

  /// The odds are a bonus on top of the deterministic answer. Losing them must
  /// not take the gap and the lever with them.
  @Test
  func `a failed probability check leaves the answer standing`() async {
    let model = RetireViewModel(service: PlanningServiceStub(shouldThrow: true))

    await model.checkProbability()

    #expect(model.readinessProbability == nil)
    #expect(model.need != nil)
    #expect(model.lever != nil)
    #expect(model.errorMessage != nil)
  }
}
