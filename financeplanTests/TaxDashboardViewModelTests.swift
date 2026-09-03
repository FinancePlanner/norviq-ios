import Foundation
import StockPlanShared
import Testing
@testable import financeplan

@MainActor
struct TaxDashboardViewModelTests {
  @Test("load populates dashboard and profile context")
  func loadSuccess() async {
    let service = TaxServiceMock()
    service.dashboardResult = .success(Self.dashboard())
    service.profileContextResult = .success(Self.profileContext())
    let model = TaxDashboardViewModel(service: service)

    await model.load()

    #expect(model.dashboard?.taxYear == 2026)
    #expect(model.profileContext?.defaultReportingCurrency == "USD")
    #expect(model.errorMessage == nil)
    #expect(model.isLoading == false)
  }

  @Test("load failure leaves dashboard empty and sets a user-facing error")
  func loadFailure() async {
    let service = TaxServiceMock()
    service.dashboardResult = .failure(TaxServiceMockError.down)
    let model = TaxDashboardViewModel(service: service)

    await model.load()

    #expect(model.dashboard == nil)
    #expect(model.errorMessage == "We couldn't refresh your tax estimate. Try again shortly.")
    #expect(model.isLoading == false)
  }

  @Test("dismiss reloads the dashboard")
  func dismissReloads() async {
    let service = TaxServiceMock()
    service.dashboardResult = .success(Self.dashboard())
    service.profileContextResult = .success(Self.profileContext())
    let model = TaxDashboardViewModel(service: service)

    await model.dismiss(Self.opportunity())

    #expect(service.dismissedIDs == ["op-1"])
    #expect(service.dashboardCalls == 1)
    #expect(model.dashboard != nil)
  }

  @Test("restore sends the selected jurisdiction and tax year")
  func restoreUsesSelectedJurisdiction() async {
    let service = TaxServiceMock()
    service.dashboardResult = .success(Self.dashboard())
    service.profileContextResult = .success(Self.profileContext())
    let model = TaxDashboardViewModel(service: service)
    model.selectedJurisdiction = .germany

    await model.restore(Self.opportunity())

    #expect(service.restoredIDs == ["op-1"])
    #expect(service.restoredJurisdictions == [.germany])
    #expect(service.restoredTaxYears == [Calendar.current.component(.year, from: Date())])
  }

  @Test("simulate stores the harvest scenario")
  func simulateStoresScenario() async {
    let service = TaxServiceMock()
    service.scenarioResult = .success(Self.scenario())
    let model = TaxDashboardViewModel(service: service)

    await model.simulate(Self.opportunity(), replacement: nil)

    #expect(model.scenario?.id == "scenario-1")
    #expect(model.errorMessage == nil)
  }

  @Test("applyScenario stores the action plan")
  func applyScenarioStoresPlan() async {
    let service = TaxServiceMock()
    service.scenarioResult = .success(Self.scenario())
    service.actionPlanResult = .success(Self.actionPlan())
    let model = TaxDashboardViewModel(service: service)
    await model.simulate(Self.opportunity(), replacement: nil)

    await model.applyScenario()

    #expect(model.actionPlan?.id == "plan-1")
  }

  @Test("simulateLocation stores the location scenario")
  func simulateLocationStoresScenario() async {
    let service = TaxServiceMock()
    service.locationScenarioResult = .success(Self.locationScenario())
    let model = TaxDashboardViewModel(service: service)

    await model.simulateLocation(Self.locationOpportunity())

    #expect(model.locationScenario?.id == "location-1")
  }

  private static func money(_ amount: Decimal) -> TaxMoney {
    TaxMoney(amount: amount, currency: "USD")
  }

  private static func dashboard() -> TaxDashboardResponse {
    TaxDashboardResponse(
      generatedAt: "2026-08-25T00:00:00Z",
      taxYear: 2026,
      jurisdiction: .unitedStates,
      ruleVersion: "test",
      isStale: false,
      profileComplete: false,
      summary: TaxProjectionSummary(
        realizedEstimatedLiability: money(0),
        embeddedUnrealizedLiability: money(1_200),
        harvestableLosses: money(400),
        estimatedNetBenefit: money(80),
        shortTermCarryover: money(0),
        longTermCarryover: money(0),
        taxCostRatio: nil
      ),
      opportunities: [],
      unsupportedValue: money(0),
      assumptions: ["test"],
      disclaimer: "Educational estimates only."
    )
  }

  private static func profileContext() -> TaxProfileContextResponse {
    TaxProfileContextResponse(
      jurisdiction: .unitedStates,
      taxYear: 2026,
      defaultReportingCurrency: "USD",
      accounts: []
    )
  }

  private static func opportunity() -> TaxOpportunityResponse {
    TaxOpportunityResponse(
      id: "op-1",
      accountId: "acct-1",
      instrumentId: "inst-1",
      symbol: "AAPL",
      instrumentType: "stock",
      status: .actionable,
      supportLevel: .supported,
      marketValue: money(1_000),
      unrealizedLoss: money(200),
      estimatedTaxBenefit: money(40),
      eligibleQuantity: 10,
      holdingPeriod: "long",
      confidence: 0.8
    )
  }

  private static func scenario() -> TaxScenarioResponse {
    let column = TaxScenarioColumn(
      currentYearTax: money(100),
      nextYearTax: money(80),
      realizedLosses: money(200),
      carryover: money(0),
      feesAndSpread: money(5)
    )
    return TaxScenarioResponse(
      id: "scenario-1",
      createdAt: "2026-08-25T00:00:00Z",
      baseline: column,
      harvestNow: column,
      estimatedNetBenefit: money(20),
      warnings: [],
      assumptions: []
    )
  }

  private static func actionPlan() -> TaxActionPlanResponse {
    TaxActionPlanResponse(
      id: "plan-1",
      scenarioId: "scenario-1",
      status: "accepted",
      createdAt: "2026-08-25T00:00:00Z",
      steps: [],
      disclaimer: "Not tax advice."
    )
  }

  private static func locationOpportunity() -> TaxLocationOpportunity {
    TaxLocationOpportunity(
      id: "loc-op-1",
      supportLevel: .estimateOnly,
      title: "Move ETF to IRA",
      annualSavings: money(120),
      immediateTaxCost: money(0),
      confidence: 0.5,
      legs: []
    )
  }

  private static func locationScenario() -> TaxLocationScenarioResponse {
    TaxLocationScenarioResponse(
      id: "location-1",
      createdAt: "2026-08-25T00:00:00Z",
      opportunities: [locationOpportunity()],
      annualSavings: money(120),
      immediateTaxCost: money(0)
    )
  }
}

private enum TaxServiceMockError: Error {
  case unexpected
  case down
}

private final class TaxServiceMock: TaxServiceProtocol, @unchecked Sendable {
  var dashboardResult: Result<TaxDashboardResponse, Error> = .failure(TaxServiceMockError.unexpected)
  var profileContextResult: Result<TaxProfileContextResponse, Error> = .failure(TaxServiceMockError.unexpected)
  var scenarioResult: Result<TaxScenarioResponse, Error> = .failure(TaxServiceMockError.unexpected)
  var actionPlanResult: Result<TaxActionPlanResponse, Error> = .failure(TaxServiceMockError.unexpected)
  var locationScenarioResult: Result<TaxLocationScenarioResponse, Error> = .failure(TaxServiceMockError.unexpected)
  var dashboardCalls = 0
  var dismissedIDs: [String] = []
  var restoredIDs: [String] = []
  var restoredJurisdictions: [TaxJurisdiction] = []
  var restoredTaxYears: [Int] = []

  func dashboard(jurisdiction _: TaxJurisdiction, taxYear _: Int) async throws -> TaxDashboardResponse {
    dashboardCalls += 1
    return try dashboardResult.get()
  }

  func profileContext(jurisdiction _: TaxJurisdiction, taxYear _: Int) async throws -> TaxProfileContextResponse {
    try profileContextResult.get()
  }

  func saveProfile(_: TaxProfileRequest) async throws -> TaxProfileResponse {
    throw TaxServiceMockError.unexpected
  }

  func saveMarketAdmission(
    instrumentId _: String,
    status _: TaxMarketAdmissionStatus
  ) async throws -> TaxInstrumentMarketOption {
    throw TaxServiceMockError.unexpected
  }

  func saveFundClassification(
    instrumentId _: String,
    classification _: TaxFundClassification
  ) async throws -> TaxInstrumentMarketOption {
    throw TaxServiceMockError.unexpected
  }

  func saveFundAnnualInput(_: TaxFundAnnualInputRequest) async throws -> TaxFundAdvanceLumpSumResponse {
    throw TaxServiceMockError.unexpected
  }

  func fundAnnualInput(
    accountId _: String,
    instrumentId _: String,
    calculationYear _: Int
  ) async throws -> TaxFundAdvanceLumpSumResponse {
    throw TaxServiceMockError.unexpected
  }

  func createScenario(
    _: TaxScenarioRequest,
    jurisdiction _: TaxJurisdiction,
    taxYear _: Int
  ) async throws -> TaxScenarioResponse {
    try scenarioResult.get()
  }

  func createActionPlan(_: TaxActionPlanRequest) async throws -> TaxActionPlanResponse {
    try actionPlanResult.get()
  }

  func actionPlans() async throws -> [TaxActionPlanResponse] {
    []
  }

  func transitionActionPlan(
    id _: String,
    request _: TaxActionPlanTransitionRequest
  ) async throws -> TaxActionPlanResponse {
    throw TaxServiceMockError.unexpected
  }

  func createLocationScenario(
    _: TaxLocationScenarioRequest,
    jurisdiction _: TaxJurisdiction,
    taxYear _: Int
  ) async throws -> TaxLocationScenarioResponse {
    try locationScenarioResult.get()
  }

  func createPlacementPlan(_: TaxPlacementPlanRequest) async throws -> TaxActionPlanResponse {
    throw TaxServiceMockError.unexpected
  }

  func dismissOpportunity(id: String, jurisdiction _: TaxJurisdiction, taxYear _: Int) async throws {
    dismissedIDs.append(id)
  }

  func restoreOpportunity(id: String, jurisdiction: TaxJurisdiction, taxYear: Int) async throws {
    restoredIDs.append(id)
    restoredJurisdictions.append(jurisdiction)
    restoredTaxYears.append(taxYear)
  }

  func notificationPreferences() async throws -> TaxNotificationPreferences {
    throw TaxServiceMockError.unexpected
  }

  func saveNotificationPreferences(_: TaxNotificationPreferences) async throws -> TaxNotificationPreferences {
    throw TaxServiceMockError.unexpected
  }

  func reports() async throws -> [TaxReportResponse] {
    []
  }

  func createReport(_: TaxReportRequest) async throws -> TaxReportResponse {
    throw TaxServiceMockError.unexpected
  }

  func downloadReport(_: TaxReportResponse) async throws -> URL {
    throw TaxServiceMockError.unexpected
  }

  func filingPreview(taxYear _: Int) async throws -> FilingPackPreviewResponse {
    throw TaxServiceMockError.unexpected
  }

  func lossCarryforwards(
    jurisdiction _: TaxJurisdiction,
    taxYear _: Int
  ) async throws -> TaxLossCarryforwardLedgerResponse {
    throw TaxServiceMockError.unexpected
  }
}
