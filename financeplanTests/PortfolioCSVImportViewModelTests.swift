import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class PortfolioCSVImportViewModelTests: XCTestCase {
  private final class BrokerServiceMock: BrokerServicing {
    var listConnectionsResult: Result<[BrokerConnectionResponse], Error> = .success([])
    var connectResult: Result<BrokerConnectionResponse, Error> = .success(
      BrokerConnectionResponse(id: UUID().uuidString, provider: "ibkr", status: "connected")
    )
    var syncResult: Result<BrokerSyncResponse, Error> = .success(
      BrokerSyncResponse(runId: UUID().uuidString, status: "completed")
    )
    var disconnectResult: Result<BrokerConnectionResponse, Error> = .success(
      BrokerConnectionResponse(id: UUID().uuidString, provider: "ibkr", status: "disconnected")
    )
    var previewResult: Result<CsvImportPreviewResponse, Error> = .success(
      CsvImportPreviewResponse(provider: "ibkr", items: [], errors: [])
    )
    var commitResult: Result<CsvImportCommitResponse, Error> = .success(
      CsvImportCommitResponse(provider: "ibkr", inserted: [], updated: [], errors: [])
    )

    func listConnections() async throws -> [BrokerConnectionResponse] {
      try listConnectionsResult.get()
    }

    func getConnection(provider: String) async throws -> BrokerConnectionResponse {
      BrokerConnectionResponse(id: UUID().uuidString, provider: provider, status: "csv")
    }

    func connectIBKR(portfolioListId: String?) async throws -> BrokerConnectionResponse {
      try connectResult.get()
    }

    func syncIBKR() async throws -> BrokerSyncResponse {
      try syncResult.get()
    }

    func disconnectIBKR() async throws -> BrokerConnectionResponse {
      try disconnectResult.get()
    }

    func previewCsvImport(provider: String, portfolioListId: String?, csvData: Data) async throws -> CsvImportPreviewResponse {
      try previewResult.get()
    }

    func commitCsvImport(provider: String, portfolioListId: String?, csvData: Data) async throws -> CsvImportCommitResponse {
      try commitResult.get()
    }
  }

  private struct StubError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }

  func testCSVImportStateTransitions_SuccessFlow() async throws {
    let brokerService = BrokerServiceMock()
    brokerService.listConnectionsResult = .success([
      BrokerConnectionResponse(id: "1", provider: "ibkr", status: "csv"),
      BrokerConnectionResponse(id: "2", provider: "degiro", status: "active")
    ])
    brokerService.previewResult = .success(
      CsvImportPreviewResponse(
        provider: "ibkr",
        items: [.init(line: 2, symbol: "AAPL", shares: 10, buyPrice: 120, buyDate: "2026-01-10", notes: nil)],
        errors: [.init(line: 3, message: "Missing symbol.")]
      )
    )
    brokerService.commitResult = .success(
      CsvImportCommitResponse(
        provider: "ibkr",
        inserted: [.init(id: "stock-1", symbol: "AAPL", shares: 10, buyPrice: 120, buyDate: "2026-01-10", notes: nil)],
        updated: [],
        errors: []
      )
    )

    let viewModel = CsvImportFlowViewModel(brokerService: brokerService)

    await viewModel.loadProvidersIfNeeded()
    XCTAssertEqual(viewModel.availableProviders, ["degiro", "ibkr"])
    XCTAssertEqual(viewModel.selectedProvider, "ibkr")

    let fileURL = makeTempCSVFile(contents: "symbol,shares,buy_price,buy_date\nAAPL,10,120,2026-01-10\n")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    await viewModel.loadCSV(from: fileURL)
    XCTAssertNotNil(viewModel.previewResponse)
    XCTAssertEqual(viewModel.previewResponse?.items.count, 1)
    XCTAssertEqual(viewModel.previewResponse?.errors.count, 1)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.canImport)

    let imported = await viewModel.commitImport()
    XCTAssertTrue(imported)
    XCTAssertEqual(viewModel.commitResponse?.inserted.count, 1)
    XCTAssertEqual(viewModel.commitResponse?.updated.count, 0)
  }

  func testPreviewFailure_PublishesErrorAndClearsPreview() async throws {
    let brokerService = BrokerServiceMock()
    brokerService.previewResult = .failure(StubError(message: "Preview failed."))

    let viewModel = CsvImportFlowViewModel(brokerService: brokerService)
    let fileURL = makeTempCSVFile(contents: "symbol,shares\nAAPL,10\n")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    await viewModel.loadCSV(from: fileURL)

    XCTAssertNil(viewModel.previewResponse)
    XCTAssertEqual(viewModel.errorMessage, "Preview failed.")
    XCTAssertFalse(viewModel.canImport)
  }

  private func makeTempCSVFile(contents: String) -> URL {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("portfolio-import-\(UUID().uuidString)")
      .appendingPathExtension("csv")
    try? contents.write(to: fileURL, atomically: true, encoding: .utf8)
    return fileURL
  }
}
