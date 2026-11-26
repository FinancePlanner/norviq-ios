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

    // Screenshot import is exercised by its own tests; these keep the mock
    // conforming without pretending to implement the flow.
    private(set) var lastScreenshotImages: [ScreenshotUploadImage]?
    private(set) var lastScreenshotCommit: ScreenshotImportCommitRequest?
    var screenshotPreviewResult: Result<ScreenshotImportPreviewResponse, Error> = .success(
      ScreenshotImportPreviewResponse(provider: "manual", kind: .unknown, items: [], errors: [], imageCount: 0)
    )

    func previewScreenshotImport(
      provider: String,
      portfolioListId: String?,
      images: [ScreenshotUploadImage]
    )
      async throws -> ScreenshotImportPreviewResponse
    {
      lastPreviewProvider = provider
      lastPreviewPortfolioListId = portfolioListId
      lastScreenshotImages = images
      return try screenshotPreviewResult.get()
    }

    func commitScreenshotImport(_ payload: ScreenshotImportCommitRequest) async throws -> CsvImportCommitResponse {
      lastScreenshotCommit = payload
      return try commitResult.get()
    }
  }

  private struct StubError: LocalizedError {
    let message: String
    var errorDescription: String? {
      message
    }
  }

  func testLockedProvider_IsWhatPreviewAndCommitSend() async throws {
    let brokerService = BrokerServiceMock()
    brokerService.previewResult = .success(
      CsvImportPreviewResponse(
        provider: "generic",
        items: [.init(line: 2, symbol: "AAPL", shares: 1, buyPrice: 1, buyDate: "2026-01-10", notes: nil)],
        errors: []
      )
    )
    brokerService.commitResult = .success(
      CsvImportCommitResponse(provider: "generic", inserted: [], updated: [], errors: [], importedLotsCount: 1)
    )
    let viewModel = CsvImportFlowViewModel(
      brokerService: brokerService,
      portfolioListId: "list-1",
      lockedProvider: "generic"
    )
    XCTAssertTrue(viewModel.isProviderLocked)
    // Even if something moves the selection, the locked provider wins.
    viewModel.selectedProvider = "ibkr"

    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).csv")
    try "symbol,shares,buy_price,buy_date\nAAPL,1,1,2026-01-10\n".write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }
    await viewModel.loadCSV(from: url)
    _ = await viewModel.commitImport()

    XCTAssertEqual(brokerService.lastPreviewProvider, "generic")
    XCTAssertEqual(brokerService.lastCommitProvider, "generic")
  }

  func testUnlockedProvider_StaysPickable() {
    let viewModel = CsvImportFlowViewModel(brokerService: BrokerServiceMock())
    XCTAssertFalse(viewModel.isProviderLocked)
  }

  func testDefaultProviderOptions_AreAvailableBeforeBackendLoad() async {
    await Task.yield()
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
        inserted: [
          .init(
            id: "stock-1",
            symbol: "AAPL",
            shares: 10,
            buyPrice: 120,
            buyDate: "2026-01-10",
            notes: nil,
            createdAt: "2026-01-10T00:00:00Z"
          )
        ],
        updated: [],
        errors: []
      )
    )

    let viewModel = CsvImportFlowViewModel(brokerService: brokerService, portfolioListId: "portfolio-1")

    await viewModel.loadProvidersIfNeeded()
    XCTAssertEqual(viewModel.availableProviders, ["generic", "ibkr", "trading212", "degiro", "revolut"])
    XCTAssertEqual(viewModel.selectedProvider, "generic")

    let fileURL = makeTempCSVFile(
      contents: "symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,core holding\n"
    )
    defer { try? FileManager.default.removeItem(at: fileURL) }

    await viewModel.loadCSV(from: fileURL)
    let csvText = try String(data: XCTUnwrap(brokerService.lastPreviewPayload), encoding: .utf8) ?? ""
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

  func testPreviewFailure_PublishesErrorAndClearsPreview() async {
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

  func testCanImport_IsFalse_WhenPreviewHasNoValidRows() async {
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

  func testCommitImport_Succeeds_WhenBackendImportsLotsOnly() async {
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
    let fileURL = makeTempCSVFile(
      contents: "symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,core holding\n"
    )
    defer { try? FileManager.default.removeItem(at: fileURL) }

    await viewModel.loadCSV(from: fileURL)

    let didImport = await viewModel.commitImport()
    XCTAssertTrue(didImport)
    XCTAssertEqual(viewModel.commitResponse?.importedLotsCount, 1)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testCommitImport_Fails_WhenBackendReturnsErrorsEvenWithInsertedRows() async {
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
          .init(
            id: "stock-1",
            symbol: "AAPL",
            shares: 10,
            buyPrice: 120,
            buyDate: "2026-01-10",
            notes: nil,
            createdAt: "2026-01-10T00:00:00Z"
          )
        ],
        updated: [],
        errors: [.init(line: 3, message: "MSFT could not be imported.")],
        importedLotsCount: 0
      )
    )

    let viewModel = CsvImportFlowViewModel(brokerService: brokerService)
    let fileURL = makeTempCSVFile(
      contents: "symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,\nMSFT,5,250,2026-01-11,\n"
    )
    defer { try? FileManager.default.removeItem(at: fileURL) }

    await viewModel.loadCSV(from: fileURL)

    let didImport = await viewModel.commitImport()
    XCTAssertFalse(didImport)
    XCTAssertEqual(viewModel.commitResponse?.inserted.count, 1)
    XCTAssertEqual(viewModel.commitResponse?.errors.count, 1)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testCommitImport_Fails_WhenNoRowsImported() async {
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

    let fileURL = makeTempCSVFile(
      contents: "symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,core holding\n"
    )
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

  func testCommitImport_Fails_WhenNoRowsImportedAndNoErrorsFromBackend() async {
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
    let fileURL = makeTempCSVFile(
      contents: "symbol,shares,buy_price,buy_date,notes\nAAPL,10,120,2026-01-10,core holding\n"
    )
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

  // MARK: - IBKR import notice (Task 10)

  private func sourceText(_ relativePath: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
  }

  func testIBKRNotice_CopyIsVerbatimForEveryConnectionStatus() async {
    let statuses: [String?] = [nil, "connected", "error", "disconnected", "csv", "active"]
    for status in statuses {
      let brokerService = BrokerServiceMock()
      if let status {
        brokerService.listConnectionsResult = .success([
          BrokerConnectionResponse(id: "1", provider: "ibkr", status: status)
        ])
      }
      let viewModel = CsvImportFlowViewModel(brokerService: brokerService)
      await viewModel.loadProviders(force: true)

      XCTAssertEqual(viewModel.ibkrNotice.title, "Import IBKR holdings", "status \(status ?? "none")")
      XCTAssertEqual(
        viewModel.ibkrNotice.body,
        "Screenshot your positions in the IBKR app or Client Portal and import them from your portfolio. Statement import with full trade history is coming next.",
        "status \(status ?? "none")"
      )
      XCTAssertEqual(viewModel.ibkrNotice.buttonTitle, "Import from broker", "status \(status ?? "none")")
    }
  }

  func testCanDisconnectIBKR_OnlyForConnectedOrError() async {
    let expectations: [(String?, Bool)] = [
      (nil, false), ("connected", true), ("error", true), ("disconnected", false), ("csv", false),
    ]
    for (status, expected) in expectations {
      let brokerService = BrokerServiceMock()
      if let status {
        brokerService.listConnectionsResult = .success([
          BrokerConnectionResponse(id: "1", provider: "ibkr", status: status)
        ])
      }
      let viewModel = CsvImportFlowViewModel(brokerService: brokerService)
      await viewModel.loadProviders(force: true)
      XCTAssertEqual(viewModel.canDisconnectIBKR, expected, "status \(status ?? "none")")
    }
  }

  func testIBKRBadge_MapsEachStatus_AndActiveIsNotConnected() async {
    let expectations: [(String?, CsvImportFlowViewModel.IBKRBadge?, Bool)] = [
      (nil, nil, false),
      ("connected", .connected, true),
      ("error", .needsAttention, true),
      ("disconnected", .notConnected, false),
      ("csv", .notConnected, false),
      ("active", .notConnected, false),
    ]
    for (status, badge, canDisconnect) in expectations {
      let brokerService = BrokerServiceMock()
      if let status {
        brokerService.listConnectionsResult = .success([
          BrokerConnectionResponse(id: "1", provider: "ibkr", status: status)
        ])
      }
      let viewModel = CsvImportFlowViewModel(brokerService: brokerService)
      await viewModel.loadProviders(force: true)
      XCTAssertEqual(viewModel.ibkrBadge, badge, "status \(status ?? "none")")
      XCTAssertEqual(viewModel.canDisconnectIBKR, canDisconnect, "status \(status ?? "none")")
    }
  }

  func testHubCopy_NoLongerPromisesConnectingIBKR() throws {
    let hub = try sourceText("financeplan/Features/UserProfile/IntegrationsHubView.swift")
    XCTAssertFalse(hub.contains("Connect Interactive Brokers today"))
    XCTAssertTrue(hub.contains("Text(\"Import holdings from IBKR and other brokers. Bank sync is read-only, always.\")"))
  }

  func testDisconnectIBKR_StillWorks() async {
    let brokerService = BrokerServiceMock()
    brokerService.listConnectionsResult = .success([
      BrokerConnectionResponse(id: "1", provider: "ibkr", status: "connected")
    ])
    let viewModel = CsvImportFlowViewModel(brokerService: brokerService)
    await viewModel.loadProviders(force: true)

    let didDisconnect = await viewModel.disconnectIBKRConnection()
    XCTAssertTrue(didDisconnect)
  }

  func testCSVFlowViewModelAndSheet_HaveNoIBKRConnectOrSyncState() throws {
    // Disconnect stays; strip it so "connectIBKR" does not match inside it.
    let viewModel = try sourceText("financeplan/API/Brokers/CsvImportFlowViewModel.swift")
      .replacingOccurrences(of: "disconnectIBKR", with: "", options: .caseInsensitive)
    let sheet = try sourceText("financeplan/Features/Portfolio/PortfolioCSVImportSheet.swift")
      .replacingOccurrences(of: "disconnectIBKR", with: "", options: .caseInsensitive)
    for needle in ["connectIBKR", "syncIBKR", "isConnectingBroker", "isSyncingBroker"] {
      XCTAssertFalse(viewModel.contains(needle), "view model still has \(needle)")
    }
    for needle in ["connectIBKR", "syncIBKR", "tokenDraft", "queryIdDraft", "isPresentingCredentials",
                   "brokerSection", "portfolioBroker", "Connect IBKR", "IBKR Broker", "Holdings import is coming soon"] {
      XCTAssertFalse(sheet.contains(needle), "CSV sheet still has \(needle)")
    }
  }

  func testIntegrationsView_HasNoConnectOrSyncActionsAndShowsNotice() throws {
    let view = try sourceText("financeplan/Features/Integrations/IntegrationsView.swift")
      .replacingOccurrences(of: "disconnectIBKR", with: "", options: .caseInsensitive)
    for needle in ["connectIBKR", "syncIBKR", "tokenDraft", "queryIdDraft", "Connect IBKR", "Sync Now",
                   "integrations.ibkr.connect", "integrations.ibkr.sync", "reportingintegration@",
                   "does not add those positions", "Holdings import is coming soon"] {
      XCTAssertFalse(view.contains(needle), "IntegrationsView still has \(needle)")
    }
    XCTAssertTrue(view.contains("integrations.ibkr.notice"))
    XCTAssertTrue(view.contains("integrations.ibkr.importFromBroker"))
  }
}
