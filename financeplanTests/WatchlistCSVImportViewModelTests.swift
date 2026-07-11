import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class WatchlistCSVImportViewModelTests: XCTestCase {
  func testWatchlistCSVImportViewModelPreviewAndCommit_PassesSelectedListId() async {
    let service = WatchlistViewModelMockStockService()
    service.previewWatchlistCsvImportResult = .success(
      WatchlistCsvImportPreviewResponse(
        watchlistListId: "tech-list",
        items: [
          WatchlistCsvImportPreviewItem(
            line: 2,
            symbol: "AAPL",
            note: "Growth",
            status: nil,
            existingItemId: nil,
            willUpdateExisting: false
          )
        ],
        errors: []
      )
    )
    service.commitWatchlistCsvImportResult = .success(
      WatchlistCsvImportCommitResponse(
        watchlistListId: "tech-list",
        inserted: [
          WatchlistItemResponse(
            id: UUID().uuidString,
            symbol: "AAPL",
            note: "Growth",
            status: .active,
            nextReviewAt: nil
          )
        ],
        updated: [],
        errors: []
      )
    )

    let viewModel = WatchlistCSVImportViewModel(watchlistListId: "tech-list", listName: "Tech", service: service)

    let csvFile = makeTempCSVFile(contents: "symbol,notes\nAAPL,Growth\n")
    defer { try? FileManager.default.removeItem(at: csvFile) }

    await viewModel.handleFileImport(.success([csvFile]))

    XCTAssertNotNil(viewModel.previewResponse)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertEqual(viewModel.previewResponse?.items.count, 1)
    XCTAssertEqual(service.lastPreviewWatchlistListId, "tech-list")
    XCTAssertEqual(service.previewWatchlistCsvImportCalls, 1)
    XCTAssertEqual(viewModel.canCommit, true)

    let didCommit = await viewModel.commitImport()

    XCTAssertTrue(didCommit)
    XCTAssertNil(viewModel.errorMessage)
    XCTAssertNotNil(viewModel.commitResponse)
    XCTAssertEqual(viewModel.commitResponse?.inserted.count, 1)
    XCTAssertEqual(service.lastCommitWatchlistListId, "tech-list")
    XCTAssertEqual(service.commitWatchlistCsvImportCalls, 1)
  }

  func testPreviewFailureSetsError() async {
    let service = WatchlistViewModelMockStockService()
    service.previewWatchlistCsvImportResult = .failure(StubError(message: "Malformed CSV"))

    let viewModel = WatchlistCSVImportViewModel(watchlistListId: "tech-list", listName: "Tech", service: service)
    let csvFile = makeTempCSVFile(contents: "symbol,notes\n,,\n")
    defer { try? FileManager.default.removeItem(at: csvFile) }

    await viewModel.handleFileImport(.success([csvFile]))

    XCTAssertNil(viewModel.previewResponse)
    XCTAssertEqual(viewModel.errorMessage, "Malformed CSV")
    XCTAssertNil(viewModel.commitResponse)
    XCTAssertEqual(service.lastPreviewWatchlistListId, "tech-list")
  }

  func testCommitFailureSetsError() async {
    let service = WatchlistViewModelMockStockService()
    service.previewWatchlistCsvImportResult = .success(
      WatchlistCsvImportPreviewResponse(watchlistListId: "tech-list", items: [
        .init(line: 2, symbol: "AAPL", note: nil, status: nil, existingItemId: nil, willUpdateExisting: false)
      ], errors: [])
    )
    service.commitWatchlistCsvImportResult = .failure(StubError(message: "Import rejected"))

    let viewModel = WatchlistCSVImportViewModel(watchlistListId: "tech-list", listName: "Tech", service: service)
    let csvFile = makeTempCSVFile(contents: "symbol,notes\nAAPL,Growth\n")
    defer { try? FileManager.default.removeItem(at: csvFile) }

    await viewModel.handleFileImport(.success([csvFile]))
    let didCommit = await viewModel.commitImport()

    XCTAssertFalse(didCommit)
    XCTAssertEqual(viewModel.errorMessage, "Import rejected")
    XCTAssertNil(viewModel.commitResponse)
    XCTAssertEqual(service.lastCommitWatchlistListId, "tech-list")
  }

  private func makeTempCSVFile(contents: String) -> URL {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("watchlist-csv-import-\(UUID().uuidString)")
      .appendingPathExtension("csv")
    try? contents.write(to: fileURL, atomically: true, encoding: .utf8)
    return fileURL
  }
}

private struct StubError: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}
