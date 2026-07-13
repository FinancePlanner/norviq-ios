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
    var holdingsValue: [ScenarioHolding] = []
    var riskProfilesValue: [ScenarioRiskProfile] = []
    var createdRun: ScenarioRunSummary?
    var snapshot = ScenarioSnapshotPreview(id: UUID(), payload: .object([:]), warnings: .array([]))
    var polledRun: ScenarioRunSummary?
    var cancelledID: UUID?

    func catalog() async throws -> ScenarioCatalogPayload { catalogValue }
    func runs() async throws -> [ScenarioRunSummary] { runsValue }
    func portfolios() async throws -> [ScenarioPortfolio] { portfoliosValue }
    func goals() async throws -> [ScenarioGoal] { goalsValue }
    func holdings(portfolioIDs: [UUID]) async throws -> [ScenarioHolding] { holdingsValue }
    func riskProfiles() async throws -> [ScenarioRiskProfile] { riskProfilesValue }
    func createGoal(name: String, portfolioID: UUID, targetAmount: Double, targetDate: Date, currency: String, monthlyContribution: Double, contributionGrowth: Double, inflation: Double) async throws -> ScenarioGoal { .init(id: UUID(), name: name, portfolioListId: portfolioID, targetAmount: targetAmount, targetDate: targetDate, baseCurrency: currency, monthlyContribution: monthlyContribution, annualContributionGrowth: contributionGrowth, inflationAssumption: inflation) }
    func updateGoal(id: UUID, name: String, portfolioID: UUID, targetAmount: Double, targetDate: Date, currency: String, monthlyContribution: Double, contributionGrowth: Double, inflation: Double) async throws -> ScenarioGoal { .init(id: id, name: name, portfolioListId: portfolioID, targetAmount: targetAmount, targetDate: targetDate, baseCurrency: currency, monthlyContribution: monthlyContribution, annualContributionGrowth: contributionGrowth, inflationAssumption: inflation) }
    func deleteGoal(id: UUID) async throws {}
    func saveRiskProfile(holdingID: UUID, assetCategory: String, sector: String?, region: String?, benchmarkProxy: String?, manualValue: Double?, duration: Double?, convexity: Double?) async throws -> ScenarioRiskProfile { .init(id: UUID(), holdingId: holdingID, assetCategory: assetCategory, sector: sector, region: region, benchmarkProxy: benchmarkProxy, manualValue: manualValue, duration: duration, convexity: convexity) }
    func deleteRiskProfile(id: UUID) async throws {}
    func captureSnapshot(portfolioID: UUID) async throws -> ScenarioSnapshotPreview { snapshot }
    func createRun(_ input: ScenarioRunRequest, snapshotID: UUID) async throws -> ScenarioRunSummary { try XCTUnwrap(createdRun) }
    func run(id: UUID) async throws -> ScenarioRunSummary { try XCTUnwrap(polledRun) }
    func cancel(runID: UUID) async throws { cancelledID = runID }
  }

  func testResultDecodesBackendSnakeCase() throws {
    let data = Data(#"{"id":"00000000-0000-0000-0000-000000000001","state":"completed","progress":1,"engineVersion":"scenario-engine-v1","errorMessage":null,"result":{"timeline":[{"elapsed_months":12,"value":125000}],"maximum_drawdown":0.18,"goal_probability":0.72,"expected_shortfall":5000}}"#.utf8)
    let run = try JSONDecoder().decode(ScenarioRunSummary.self, from: data)
    XCTAssertEqual(run.result?.timeline?.first?.elapsedMonths, 12)
    XCTAssertEqual(run.result?.maximumDrawdown, 0.18)
    XCTAssertEqual(run.result?.goalProbability, 0.72)
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
    await model.capture(.init(name: "Test", portfolioID: UUID(), goalID: nil, kind: .monteCarlo, catalogID: "", shock: 0, horizonMonths: 360, pathCount: 10_000, distribution: "normal", seed: 42, save: true))
    XCTAssertEqual(model.snapshotPreview?.id, service.snapshot.id)
    await model.runReviewedSnapshot()
    XCTAssertEqual(model.runs.first?.id, run.id)
    XCTAssertFalse(model.isSubmitting)
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
