import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class PortfolioCSVImportViewModelTests: XCTestCase {
  private final class BrokerServiceMock: BrokerServicing, @unchecked Sendable {
    private(set) var lastPreviewProvider: String?
    private(set) var lastCommitProvider: String?
    private(set) var lastPreviewPortfolioListId: String?
    private(set) var lastCommitPortfolioListId: String?
    private(set) var lastPreviewPayload: Data?
    private(set) var lastCommitPayload: Data?

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

    func connectIBKRCredentials(token: String, queryId: String, portfolioListId: String?) async throws -> BrokerConnectionResponse {
      _ = token
      _ = queryId
      _ = portfolioListId
      return try connectResult.get()
    }

    func syncIBKR() async throws -> BrokerSyncResponse {
      try syncResult.get()
    }

    func disconnectIBKR() async throws -> BrokerConnectionResponse {
      try disconnectResult.get()
    }

    func previewCsvImport(provider: String, portfolioListId: String?, csvData: Data) async throws -> CsvImportPreviewResponse {
      lastPreviewProvider = provider
      lastPreviewPortfolioListId = portfolioListId
      lastPreviewPayload = csvData
      return try previewResult.get()
    }

    func commitCsvImport(provider: String, portfolioListId: String?, csvData: Data) async throws -> CsvImportCommitResponse {
      lastCommitProvider = provider
      lastCommitPortfolioListId = portfolioListId
      lastCommitPayload = csvData
      return try commitResult.get()
    }
  }

  private struct StubError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }

  func testDefaultProviderOptions_AreAvailableBeforeBackendLoad() {
    let viewModel = CsvImportFlowViewModel(brokerService: BrokerServiceMock())

    XCTAssertEqual(viewModel.selectedProvider, "generic")
    XCTAssertEqual(viewModel.availableProviders, ["generic", "ibkr", "trading212", "degiro", "revolut"])
    XCTAssertFalse(viewModel.canImport)
  }

  func testLoadProviders_MergesBackendConnectionsWithFallbackProviders() async {
    let brokerService = BrokerServiceMock()
    brokerService.listConnectionsResult = .success([
      BrokerConnectionResponse(id: "1", provider: "ibkr", status: "connected")
    ])
    let viewModel = CsvImportFlowViewModel(brokerService: brokerService)

    await viewModel.loadProvidersIfNeeded()

    XCTAssertEqual(viewModel.availableProviders, ["generic", "ibkr", "trading212", "degiro", "revolut"])
    XCTAssertEqual(viewModel.selectedProvider, "generic")
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
        inserted: [.init(id: "stock-1", symbol: "AAPL", shares: 10, buyPrice: 120, buyDate: "2026-01-10", notes: nil, createdAt: "2026-01-10T00:00:00Z")],
        updated: [],
        errors: []
      )
    )

    let viewModel = CsvImportFlowViewModel(brokerService: brokerService, portfolioListId: "portfolio-1")

    await viewModel.loadProvidersIfNeeded()
    XCTAssertEqual(viewModel.availableProviders, ["generic", "ibkr", "trading212", "degiro", "revolut"])
    XCTAssertEqual(viewModel.selectedProvider, "generic")

    let fileURL = makeTempCSVFile(contents: "symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,core holding\n")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    await viewModel.loadCSV(from: fileURL)
    let csvText = String(data: try XCTUnwrap(brokerService.lastPreviewPayload), encoding: .utf8) ?? ""
    XCTAssertEqual(csvText, "symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,core holding\n")
    XCTAssertEqual(brokerService.lastPreviewProvider, "generic")
    XCTAssertEqual(brokerService.lastPreviewPortfolioListId, "portfolio-1")
    XCTAssertNotNil(viewModel.previewResponse)
    XCTAssertEqual(viewModel.previewResponse?.items.count, 1)
    XCTAssertEqual(viewModel.previewResponse?.errors.count, 1)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.canImport)

    let imported = await viewModel.commitImport()
    XCTAssertTrue(imported)
    XCTAssertEqual(brokerService.lastCommitProvider, "generic")
    XCTAssertEqual(brokerService.lastCommitPortfolioListId, "portfolio-1")
    XCTAssertEqual(viewModel.commitResponse?.inserted.count, 1)
    XCTAssertEqual(viewModel.commitResponse?.updated.count, 0)
    XCTAssertEqual(viewModel.commitResponse?.importedLotsCount, 0)
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

  func testCanImport_IsFalse_WhenPreviewHasNoValidRows() async throws {
    let brokerService = BrokerServiceMock()
    brokerService.previewResult = .success(
      CsvImportPreviewResponse(
        provider: "generic",
        items: [],
        errors: [.init(line: 2, message: "Missing symbol.")]
      )
    )

    let viewModel = CsvImportFlowViewModel(brokerService: brokerService)
    XCTAssertFalse(viewModel.canImport)

    let fileURL = makeTempCSVFile(contents: "symbol,shares,buy_price,buy_date,notes\n,10,120,2026-01-10,\n")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    await viewModel.loadCSV(from: fileURL)

    XCTAssertEqual(viewModel.previewResponse?.items.count, 0)
    XCTAssertFalse(viewModel.canImport)

    let didImport = await viewModel.commitImport()
    XCTAssertFalse(didImport)
    XCTAssertEqual(viewModel.errorMessage, "No valid rows to import.")
  }

  func testCommitImport_Succeeds_WhenBackendImportsLotsOnly() async throws {
    let brokerService = BrokerServiceMock()
    brokerService.previewResult = .success(
      CsvImportPreviewResponse(
        provider: "generic",
        items: [.init(line: 2, symbol: "AAPL", shares: 10, buyPrice: 120, buyDate: "2026-01-10", notes: nil)],
        errors: []
      )
    )
    brokerService.commitResult = .success(
      CsvImportCommitResponse(
        provider: "generic",
        inserted: [],
        updated: [],
        errors: [],
        importedLotsCount: 1
      )
    )

    let viewModel = CsvImportFlowViewModel(brokerService: brokerService)
    let fileURL = makeTempCSVFile(contents: "symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,core holding\n")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    await viewModel.loadCSV(from: fileURL)

    let didImport = await viewModel.commitImport()
    XCTAssertTrue(didImport)
    XCTAssertEqual(viewModel.commitResponse?.importedLotsCount, 1)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testCommitImport_Fails_WhenBackendReturnsErrorsEvenWithInsertedRows() async throws {
    let brokerService = BrokerServiceMock()
    brokerService.previewResult = .success(
      CsvImportPreviewResponse(
        provider: "generic",
        items: [
          .init(line: 2, symbol: "AAPL", shares: 10, buyPrice: 120, buyDate: "2026-01-10", notes: nil),
          .init(line: 3, symbol: "MSFT", shares: 5, buyPrice: 250, buyDate: "2026-01-11", notes: nil),
        ],
        errors: []
      )
    )
    brokerService.commitResult = .success(
      CsvImportCommitResponse(
        provider: "generic",
        inserted: [
          .init(id: "stock-1", symbol: "AAPL", shares: 10, buyPrice: 120, buyDate: "2026-01-10", notes: nil, createdAt: "2026-01-10T00:00:00Z")
        ],
        updated: [],
        errors: [.init(line: 3, message: "MSFT could not be imported.")],
        importedLotsCount: 0
      )
    )

    let viewModel = CsvImportFlowViewModel(brokerService: brokerService)
    let fileURL = makeTempCSVFile(contents: "symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,\nMSFT,5,250,2026-01-11,\n")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    await viewModel.loadCSV(from: fileURL)

    let didImport = await viewModel.commitImport()
    XCTAssertFalse(didImport)
    XCTAssertEqual(viewModel.commitResponse?.inserted.count, 1)
    XCTAssertEqual(viewModel.commitResponse?.errors.count, 1)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testCommitImport_Fails_WhenNoRowsImported() async throws {
    let brokerService = BrokerServiceMock()
    brokerService.previewResult = .success(
      CsvImportPreviewResponse(
        provider: "generic",
        items: [.init(line: 2, symbol: "AAPL", shares: 10, buyPrice: 120, buyDate: "2026-01-10", notes: nil)],
        errors: []
      )
    )
    brokerService.commitResult = .success(
      CsvImportCommitResponse(
        provider: "generic",
        inserted: [],
        updated: [],
        errors: [.init(line: 2, message: "Symbol not supported.")],
        importedLotsCount: 0
      )
    )

    let viewModel = CsvImportFlowViewModel(brokerService: brokerService)

    let fileURL = makeTempCSVFile(contents: "symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,core holding\n")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    await viewModel.loadCSV(from: fileURL)

    XCTAssertTrue(viewModel.canImport)
    let didImport = await viewModel.commitImport()
    XCTAssertFalse(didImport)
    XCTAssertEqual(viewModel.commitResponse?.errors.count, 1)
    XCTAssertEqual(viewModel.commitResponse?.inserted.count, 0)
    XCTAssertEqual(viewModel.commitResponse?.updated.count, 0)
    XCTAssertEqual(viewModel.commitResponse?.importedLotsCount, 0)
  }

  func testCommitImport_Fails_WhenNoRowsImportedAndNoErrorsFromBackend() async throws {
    let brokerService = BrokerServiceMock()
    brokerService.previewResult = .success(
      CsvImportPreviewResponse(
        provider: "generic",
        items: [.init(line: 2, symbol: "AAPL", shares: 10, buyPrice: 120, buyDate: "2026-01-10", notes: nil)],
        errors: []
      )
    )
    brokerService.commitResult = .success(
      CsvImportCommitResponse(
        provider: "generic",
        inserted: [],
        updated: [],
        errors: [],
        importedLotsCount: 0
      )
    )

    let viewModel = CsvImportFlowViewModel(brokerService: brokerService)
    let fileURL = makeTempCSVFile(contents: "symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,core holding\n")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    await viewModel.loadCSV(from: fileURL)

    XCTAssertTrue(viewModel.canImport)
    let didImport = await viewModel.commitImport()
    XCTAssertFalse(didImport)
    XCTAssertEqual(viewModel.errorMessage, "No rows were imported.")
    XCTAssertEqual(viewModel.commitResponse?.inserted.count, 0)
    XCTAssertEqual(viewModel.commitResponse?.updated.count, 0)
    XCTAssertEqual(viewModel.commitResponse?.importedLotsCount, 0)
  }

  private func makeTempCSVFile(contents: String) -> URL {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("portfolio-import-\(UUID().uuidString)")
      .appendingPathExtension("csv")
    try? contents.write(to: fileURL, atomically: true, encoding: .utf8)
    return fileURL
  }
}
