import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

/// Every test is async: a synchronous test method in this @MainActor XCTestCase
/// aborts with SIGABRT under Swift 6 once it touches the view model, even though
/// the body runs and produces correct values.
@MainActor
final class PortfolioSimulatorTests: XCTestCase {

  // MARK: - Weight arithmetic

  func testCashIsWhateverTheLegsDoNotClaim() async {
    await Task.yield()
    let viewModel = PortfolioSimulatorViewModel(service: ServiceMock())
    viewModel.legs = [leg("AAPL", 30), leg("MSFT", 20)]

    XCTAssertEqual(viewModel.claimedBasisPoints, 5000)
    XCTAssertEqual(viewModel.cashBasisPoints, 5000)
    XCTAssertFalse(viewModel.isOverAllocated)
    XCTAssertTrue(viewModel.canSimulate)
  }

  func testAFullyAllocatedDraftHoldsNoCash() async {
    await Task.yield()
    let viewModel = PortfolioSimulatorViewModel(service: ServiceMock())
    viewModel.legs = [leg("AAPL", 60), leg("MSFT", 40)]

    XCTAssertEqual(viewModel.cashBasisPoints, 0)
    XCTAssertFalse(viewModel.isOverAllocated)
  }

  func testOverAllocationBlocksSimulationAndNeverGoesNegative() async {
    await Task.yield()
    let viewModel = PortfolioSimulatorViewModel(service: ServiceMock())
    viewModel.legs = [leg("AAPL", 60), leg("MSFT", 50)]

    XCTAssertTrue(viewModel.isOverAllocated)
    XCTAssertEqual(viewModel.cashBasisPoints, 0)
    XCTAssertFalse(viewModel.canSimulate)
  }

  func testEqualWeightSpreadsAcrossNamedPositionsOnly() async {
    await Task.yield()
    let viewModel = PortfolioSimulatorViewModel(service: ServiceMock())
    viewModel.legs = [leg("AAPL", 0), leg("MSFT", 0), PortfolioSimulatorViewModel.Leg()]
    viewModel.equalWeight()

    XCTAssertEqual(viewModel.legs[0].weightPercent, 50)
    XCTAssertEqual(viewModel.legs[1].weightPercent, 50)
    // The blank row is left alone rather than being handed a share of the portfolio.
    XCTAssertEqual(viewModel.legs[2].weightPercent, 0)
  }

  func testRemovingEveryRowLeavesOneToTypeInto() async {
    await Task.yield()
    let viewModel = PortfolioSimulatorViewModel(service: ServiceMock())
    viewModel.legs = [leg("AAPL", 50)]
    viewModel.removeLeg(at: IndexSet(integer: 0))

    XCTAssertEqual(viewModel.legs.count, 1)
    XCTAssertFalse(viewModel.legs[0].isFilled)
  }

  // MARK: - Request shaping

  func testOnlyFilledRowsAreSentAndSymbolsAreNormalised() async {
    let service = ServiceMock()
    let viewModel = PortfolioSimulatorViewModel(service: service)
    viewModel.legs = [leg(" aapl ", 40), PortfolioSimulatorViewModel.Leg(), leg("MSFT", 0)]
    service.previewResult = Self.result(cashBasisPoints: 6000)

    await viewModel.simulate()

    let request = try? XCTUnwrap(service.lastPreviewRequest)
    XCTAssertEqual(request?.legs.count, 1)
    XCTAssertEqual(request?.legs.first?.symbol, "AAPL")
    XCTAssertEqual(request?.legs.first?.targetBasisPoints, 4000)
    XCTAssertEqual(request?.mode, .fromScratch)
  }

  func testChoosingAPortfolioSwitchesTheSimulationToCloneMode() async {
    let service = ServiceMock()
    let viewModel = PortfolioSimulatorViewModel(service: service)
    viewModel.legs = [leg("AAPL", 50)]
    viewModel.sourcePortfolioId = "portfolio-1"
    service.previewResult = Self.result(cashBasisPoints: 5000)

    await viewModel.simulate()

    XCTAssertEqual(service.lastPreviewRequest?.mode, .cloneCurrentPortfolio)
    XCTAssertEqual(service.lastPreviewRequest?.sourcePortfolioId, "portfolio-1")
  }

  // MARK: - Failure handling

  func testABackendRejectionIsSurfacedVerbatim() async {
    let service = ServiceMock()
    service.previewError = StockHTTPClient.Error.api("No current price is available for NOSUCHTICKER.")
    let viewModel = PortfolioSimulatorViewModel(service: service)
    viewModel.legs = [leg("NOSUCHTICKER", 50)]

    await viewModel.simulate()

    // The backend names the offending ticker; a generic message would throw that away.
    XCTAssertEqual(viewModel.errorMessage, "No current price is available for NOSUCHTICKER.")
    XCTAssertNil(viewModel.result)
  }

  func testMissingPortfoliosIsNotTreatedAsAnError() async {
    let service = ServiceMock()
    service.portfoliosError = StockHTTPClient.Error.invalidStatus(500)
    let viewModel = PortfolioSimulatorViewModel(service: service)

    await viewModel.loadPortfolios()

    XCTAssertTrue(viewModel.portfolios.isEmpty)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testTheRoundingNoteOnlyShowsWhenWholeSharesLeftCashBehind() async {
    let service = ServiceMock()
    let viewModel = PortfolioSimulatorViewModel(service: service)
    viewModel.legs = [leg("AAPL", 100)]
    viewModel.fractionalSharesEnabled = false
    service.previewResult = Self.result(cashBasisPoints: 0, leftoverCash: 74.40)

    await viewModel.simulate()
    XCTAssertTrue(viewModel.showsRoundingNote)

    viewModel.fractionalSharesEnabled = true
    XCTAssertFalse(viewModel.showsRoundingNote)
  }

  // MARK: - Helpers

  private func leg(_ symbol: String, _ percent: Double) -> PortfolioSimulatorViewModel.Leg {
    var leg = PortfolioSimulatorViewModel.Leg()
    leg.symbol = symbol
    leg.weightPercent = percent
    return leg
  }

  private static func result(
    cashBasisPoints: Int,
    leftoverCash: Double = 0
  ) -> PortfolioSimulationResult {
    PortfolioSimulationResult(
      simulationId: "sim-1",
      revision: 1,
      mode: .fromScratch,
      generatedAt: "2026-09-12T12:00:00Z",
      simulation: SimulationDetail(
        baseCurrency: "USD",
        totalValueBefore: 10000,
        totalValueAfter: 10000,
        estimatedFees: 0,
        trades: [],
        after: []
      ),
      totalCashNeeded: 10000 - leftoverCash,
      leftoverCash: leftoverCash,
      cashBasisPoints: cashBasisPoints,
      diff: [],
      warnings: []
    )
  }

  private final class ServiceMock: PortfolioSimulationServicing, @unchecked Sendable {
    var previewResult: PortfolioSimulationResult?
    var previewError: (any Error)?
    var portfoliosError: (any Error)?
    private(set) var lastPreviewRequest: PortfolioSimulationUpsertRequest?

    func list() async throws -> [PortfolioSimulation] {
      []
    }

    func detail(simulationId _: String) async throws -> PortfolioSimulation {
      throw StockHTTPClient.Error.invalidResponse
    }

    func create(_ input: PortfolioSimulationUpsertRequest) async throws -> PortfolioSimulation {
      lastPreviewRequest = input
      throw StockHTTPClient.Error.invalidResponse
    }

    func update(
      simulationId _: String,
      input _: PortfolioSimulationUpsertRequest
    )
      async throws -> PortfolioSimulation
    {
      throw StockHTTPClient.Error.invalidResponse
    }

    func delete(simulationId _: String) async throws {}

    func preview(_ input: PortfolioSimulationUpsertRequest) async throws -> PortfolioSimulationResult {
      lastPreviewRequest = input
      if let previewError {
        throw previewError
      }
      guard let previewResult else { throw StockHTTPClient.Error.invalidResponse }
      return previewResult
    }

    func compute(
      simulationId _: String,
      capitalOverride _: Double?
    )
      async throws -> PortfolioSimulationResult
    {
      guard let previewResult else { throw StockHTTPClient.Error.invalidResponse }
      return previewResult
    }

    func portfolios() async throws -> [PortfolioListDTOResponse] {
      if let portfoliosError {
        throw portfoliosError
      }
      return []
    }
  }
}
