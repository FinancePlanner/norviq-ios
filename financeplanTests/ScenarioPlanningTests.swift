import Foundation
import XCTest
@testable import financeplan

@MainActor
final class ScenarioPlanningTests: XCTestCase {
  private final class ServiceMock: ScenarioPlanningServiceProtocol, @unchecked Sendable {
    var catalogValue = ScenarioCatalogPayload(version: "historical-v1", historicalScenarios: [])
    var runsValue: [ScenarioRunSummary] = []
    var portfoliosValue: [ScenarioPortfolio] = []
    var goalsValue: [ScenarioGoal] = []
    var scenariosValue: [ScenarioDefinitionSummary] = []
    var holdingsValue: [ScenarioHolding] = []
    var cryptoHoldingsValue: [ScenarioCryptoHolding] = []
    var riskProfilesValue: [ScenarioRiskProfile] = []
    var createdRun: ScenarioRunSummary?
    var snapshot = ScenarioSnapshotPreview(id: UUID(), payload: .object([:]), warnings: .array([]))
    var polledRun: ScenarioRunSummary?
    var cancelledID: UUID?
    var createdScenarioID: UUID?
    var deletedScenarioID: UUID?
    var capturedBaseCurrency: String?
    var capturedCryptoHoldingIDs: [UUID] = []

    func catalog() async throws -> ScenarioCatalogPayload { catalogValue }
    func runs() async throws -> [ScenarioRunSummary] { runsValue }
    func scenarios() async throws -> [ScenarioDefinitionSummary] { scenariosValue }
    func portfolios() async throws -> [ScenarioPortfolio] { portfoliosValue }
    func goals() async throws -> [ScenarioGoal] { goalsValue }
    func cryptoHoldings() async throws -> [ScenarioCryptoHolding] { cryptoHoldingsValue }
    func holdings(portfolioIDs: [UUID]) async throws -> [ScenarioHolding] { holdingsValue }
    func riskProfiles() async throws -> [ScenarioRiskProfile] { riskProfilesValue }
    func createGoal(name: String, portfolioID: UUID, targetAmount: Double, targetDate: Date, currency: String, monthlyContribution: Double, contributionGrowth: Double, inflation: Double) async throws -> ScenarioGoal { .init(id: UUID(), name: name, portfolioListId: portfolioID, targetAmount: targetAmount, targetDate: targetDate, baseCurrency: currency, monthlyContribution: monthlyContribution, annualContributionGrowth: contributionGrowth, inflationAssumption: inflation) }
    func updateGoal(id: UUID, name: String, portfolioID: UUID, targetAmount: Double, targetDate: Date, currency: String, monthlyContribution: Double, contributionGrowth: Double, inflation: Double) async throws -> ScenarioGoal { .init(id: id, name: name, portfolioListId: portfolioID, targetAmount: targetAmount, targetDate: targetDate, baseCurrency: currency, monthlyContribution: monthlyContribution, annualContributionGrowth: contributionGrowth, inflationAssumption: inflation) }
    func deleteGoal(id: UUID) async throws {}
    func saveRiskProfile(holdingID: UUID, assetCategory: String, sector: String?, region: String?, benchmarkProxy: String?, manualValue: Double?, duration: Double?, convexity: Double?) async throws -> ScenarioRiskProfile { .init(id: UUID(), holdingId: holdingID, assetCategory: assetCategory, sector: sector, region: region, benchmarkProxy: benchmarkProxy, manualValue: manualValue, duration: duration, convexity: convexity) }
    func deleteRiskProfile(id: UUID) async throws {}
    func captureSnapshot(portfolioID: UUID, baseCurrency: String, cryptoHoldingIDs: [UUID]) async throws -> ScenarioSnapshotPreview {
      capturedBaseCurrency = baseCurrency
      capturedCryptoHoldingIDs = cryptoHoldingIDs
      return snapshot
    }
    func createRun(_ input: ScenarioRunRequest, snapshotID: UUID) async throws -> ScenarioRunSummary { try XCTUnwrap(createdRun) }
    func createRun(scenarioID: UUID, snapshotID: UUID, seed: Int64?) async throws -> ScenarioRunSummary { createdScenarioID = scenarioID; return try XCTUnwrap(createdRun) }
    func deleteScenario(id: UUID) async throws { deletedScenarioID = id }
    func run(id: UUID) async throws -> ScenarioRunSummary { try XCTUnwrap(polledRun) }
    func cancel(runID: UUID) async throws { cancelledID = runID }
  }

  func testResultDecodesBackendSnakeCase() throws {
    let data = Data(#"{"id":"00000000-0000-0000-0000-000000000001","state":"completed","progress":1,"engineVersion":"scenario-engine-v1","errorMessage":null,"result":{"timeline":[{"elapsed_months":12,"value":125000}],"maximum_drawdown":0.18,"goal_probability":0.72,"expected_shortfall":5000,"ending_value":78000,"portfolio_change_percent":-0.22,"goal_delay_months":14,"required_monthly_contribution":680,"contribution_delta":180,"recovery_months":18,"expense_impact_monthly":180}}"#.utf8)
    let run = try JSONDecoder().decode(ScenarioRunSummary.self, from: data)
    XCTAssertEqual(run.result?.timeline?.first?.elapsedMonths, 12)
    XCTAssertEqual(run.result?.maximumDrawdown, 0.18)
    XCTAssertEqual(run.result?.goalProbability, 0.72)
    XCTAssertEqual(run.result?.endingValue, 78_000)
    XCTAssertEqual(run.result?.portfolioChangePercent, -0.22)
    XCTAssertEqual(run.result?.goalDelayMonths, 14)
    XCTAssertEqual(run.result?.contributionDelta, 180)
    XCTAssertEqual(run.result?.recoveryMonths, 18)
    XCTAssertEqual(run.result?.expenseImpactMonthly, 180)
  }

  func testResultDecodesPercentileFan() throws {
    let data = Data(#"{"id":"00000000-0000-0000-0000-000000000001","state":"completed","progress":1,"engineVersion":"scenario-engine-v1","errorMessage":null,"result":{"percentile_bands":[{"elapsed_months":12,"p10":90,"p25":100,"p50":120,"p75":130,"p90":150}],"maximum_drawdown":0.2}}"#.utf8)
    let run = try JSONDecoder().decode(ScenarioRunSummary.self, from: data)
    XCTAssertEqual(run.result?.percentileBands?.first?.elapsedMonths, 12)
    XCTAssertEqual(run.result?.percentileBands?.first?.p50, 120)
  }

  func testViewModelLoadsWorkspaceAndPollsActiveRun() async throws {
    let service = ServiceMock()
    let id = UUID()
    service.portfoliosValue = [.init(id: UUID(), name: "Core", isDefault: true)]
    service.goalsValue = [.init(id: UUID(), name: "Retirement", portfolioListId: nil, targetAmount: nil, targetDate: nil, baseCurrency: nil, monthlyContribution: nil, annualContributionGrowth: nil, inflationAssumption: nil)]
    service.runsValue = [.init(id: id, state: "running", progress: 0.25, engineVersion: "v1", errorMessage: nil, result: nil)]
    service.polledRun = .init(id: id, state: "completed", progress: 1, engineVersion: "v1", errorMessage: nil, result: nil)
    let model = ScenarioPlanningViewModel(service: service)
    await model.load()
    XCTAssertEqual(model.portfolios.count, 1)
    XCTAssertEqual(model.goals.count, 1)
    await model.poll()
    XCTAssertEqual(model.runs.first?.state, "completed")
    XCTAssertEqual(model.runs.first?.progress, 1)
  }

  func testSubmitPrependsQueuedRun() async throws {
    let service = ServiceMock()
    let run = ScenarioRunSummary(id: UUID(), state: "queued", progress: 0, engineVersion: "v1", errorMessage: nil, result: nil)
    service.createdRun = run
    let model = ScenarioPlanningViewModel(service: service)
    let cryptoID = UUID()
    await model.capture(.init(name: "Test", portfolioID: UUID(), goalID: nil, kind: .monteCarlo, catalogID: "", shock: 0, horizonMonths: 360, pathCount: 10_000, distribution: "normal", seed: 42, save: true), baseCurrency: "EUR", cryptoHoldingIDs: [cryptoID])
    XCTAssertEqual(model.snapshotPreview?.id, service.snapshot.id)
    XCTAssertEqual(service.capturedBaseCurrency, "EUR")
    XCTAssertEqual(service.capturedCryptoHoldingIDs, [cryptoID])
    await model.runReviewedSnapshot()
    XCTAssertEqual(model.runs.first?.id, run.id)
    XCTAssertFalse(model.isSubmitting)
  }

  func testSavedScenarioRequiresSnapshotReviewAndCanRunAgain() async throws {
    let service = ServiceMock()
    let scenario = ScenarioDefinitionSummary(
      id: UUID(), portfolioListId: UUID(), financialGoalId: nil, name: "Saved",
      kind: "monte_carlo", configuration: .object([:]), isSaved: true
    )
    let run = ScenarioRunSummary(id: UUID(), state: "queued", progress: 0, engineVersion: "v1", errorMessage: nil, result: nil)
    service.createdRun = run
    let model = ScenarioPlanningViewModel(service: service)
    await model.capture(scenario, seed: 99, baseCurrency: "GBP", cryptoHoldingIDs: [])
    XCTAssertEqual(model.snapshotPreview?.id, service.snapshot.id)
    XCTAssertEqual(service.capturedBaseCurrency, "GBP")
    await model.runReviewedSnapshot()
    XCTAssertEqual(service.createdScenarioID, scenario.id)
    XCTAssertEqual(model.runs.first?.id, run.id)
  }

  func testPrivatePDFReportIsReadable() throws {
    let result = ScenarioResultPayload(
      timeline: [
        .init(elapsedMonths: 0, value: 100_000),
        .init(elapsedMonths: 12, value: 112_000),
      ],
      percentileBands: nil, maximumDrawdown: 0.12, goalProbability: 0.74,
      expectedShortfall: 8_000,
      assumptions: .object(["distribution": .string("normal")]),
      warnings: .array([.object(["message": .string("Used benchmark proxy SPY.")])])
    )
    let run = ScenarioRunSummary(
      id: UUID(), state: "completed", progress: 1, engineVersion: "scenario-engine-v1",
      errorMessage: nil, result: result
    )
    let url = try ScenarioPDFReport.render(run: run, result: result)
    let data = try Data(contentsOf: url)
    XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
    XCTAssertGreaterThan(data.count, 1_000)
  }

  func testMultiAssetAssumptionsDecodeAndValidate() throws {
    let result = try parseScenarioMultiAssetAssumptions(
      weights: "[0.6, 0.4]",
      annualReturns: "[0.08, 0.04]",
      covariance: "[[0.04, 0.006], [0.006, 0.01]]"
    )
    XCTAssertEqual(result.weights, [0.6, 0.4])
    XCTAssertEqual(result.annualReturns, [0.08, 0.04])
    XCTAssertEqual(result.covariance[1][0], 0.006)
  }

  func testMultiAssetAssumptionsRejectDimensionMismatch() {
    XCTAssertThrowsError(try parseScenarioMultiAssetAssumptions(
      weights: "[0.6, 0.4]",
      annualReturns: "[0.08]",
      covariance: "[[0.04, 0.006], [0.006, 0.01]]"
    )) { error in
      XCTAssertEqual(error as? ScenarioMultiAssetValidationError, .invalidDimensions)
    }
  }
}
