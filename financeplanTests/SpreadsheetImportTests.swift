import Foundation
import StockPlanShared
import XCTest
@testable import financeplan

@MainActor
final class SpreadsheetImportTests: XCTestCase {
  private final class SessionMock: HTTPClientSession, @unchecked Sendable {
    var handler: ((URLRequest) throws -> (Data, URLResponse))?
    private(set) var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
      requests.append(request)
      guard let handler else {
        fatalError("SessionMock.handler must be configured before use")
      }
      return try handler(request)
    }
  }

  private func makeClient(_ session: SessionMock) -> SpreadsheetImportHTTPClient {
    SpreadsheetImportHTTPClient(
      baseURL: URL(string: "https://api.example.com")!,
      session: session,
      authTokenProvider: { "token-123" }
    )
  }

  private func ok(_ request: URLRequest) throws -> HTTPURLResponse {
    try XCTUnwrap(
      HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
    )
  }

  private func makeAnalysis(
    importable: Int = 2,
    rows: [SpreadsheetImportPreviewRow] = []
  ) -> SpreadsheetImportAnalysisResponse {
    SpreadsheetImportAnalysisResponse(
      sessionId: "session-1",
      fileName: "budget.xlsx",
      expiresAt: "2026-07-31T12:00:00Z",
      sheets: [
        .init(
          name: "Despesas", index: 0, rowCount: 7, headerRow: 4, dataStartRow: 5, dataEndRow: 9,
          include: true, isRecommended: true,
          columns: [
            .init(letter: "D", header: "Data", detectedType: "date", field: .date,
                  confidence: 0.9, source: .heuristic),
            .init(letter: "G", header: "Valor", detectedType: "currencyAmount", field: .amount,
                  confidence: 0.9, source: .heuristic),
          ]
        ),
      ],
      preview: .init(
        totalRows: rows.isEmpty ? 2 : rows.count,
        importableRows: importable,
        duplicateRows: 0,
        needsAttentionRows: 0,
        excludedRows: 0,
        totalAmount: 98.19,
        rows: rows
      ),
      aiAvailable: true
    )
  }

  // MARK: - Upload

  func testAnalyzeSendsMultipartWithBearerToken() async throws {
    let session = SessionMock()
    let client = makeClient(session)
    let expected = makeAnalysis()

    session.handler = { request in
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(request.url?.path, "/v1/expenses/import/spreadsheet")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
      let contentType = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
      XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))
      // The backend reads the field named "file".
      let body = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
      XCTAssertTrue(body.contains("name=\"file\""))
      XCTAssertTrue(body.contains("filename=\"budget.xlsx\""))
      return (try JSONEncoder.stockPlanShared.encode(expected), try self.ok(request))
    }

    let response = try await client.analyze(fileData: Data("fake".utf8), filename: "budget.xlsx")
    XCTAssertEqual(response.sessionId, "session-1")
  }

  /// A retried commit must not insert the same expenses twice.
  func testCommitSendsIdempotencyKey() async throws {
    let session = SessionMock()
    let client = makeClient(session)
    let expected = SpreadsheetImportCommitResponse(
      sessionId: "session-1", imported: 5, skipped: 1, failed: 0
    )

    session.handler = { request in
      XCTAssertEqual(request.url?.path, "/v1/expenses/import/spreadsheet/session-1/commit")
      XCTAssertFalse(
        (request.value(forHTTPHeaderField: "Idempotency-Key") ?? "").isEmpty,
        "commit must be idempotent so a retry cannot double-insert"
      )
      return (try JSONEncoder.stockPlanShared.encode(expected), try self.ok(request))
    }

    let response = try await client.commit(
      sessionId: "session-1",
      decision: SpreadsheetImportDecisionRequest(sheets: [])
    )
    XCTAssertEqual(response.imported, 5)
  }

  /// 404 here means the hour-long session lapsed mid-review; the message should
  /// tell the user what to do rather than show a status code.
  func testExpiredSessionProducesActionableMessage() async throws {
    let session = SessionMock()
    let client = makeClient(session)

    session.handler = { request in
      let response = try XCTUnwrap(
        HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 404, httpVersion: nil, headerFields: nil)
      )
      return (Data("{}".utf8), response)
    }

    do {
      _ = try await client.fetch(sessionId: "session-1")
      XCTFail("expected the request to fail")
    } catch {
      XCTAssertTrue(
        error.localizedDescription.lowercased().contains("upload the file again"),
        "got: \(error.localizedDescription)"
      )
    }
  }

  // MARK: - View model

  func testAnalyzePopulatesReviewState() async throws {
    let session = SessionMock()
    let client = makeClient(session)
    let expected = makeAnalysis()
    session.handler = { request in
      (try JSONEncoder.stockPlanShared.encode(expected), try self.ok(request))
    }

    let viewModel = SpreadsheetImportViewModel(client: client)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("budget.xlsx")
    try Data("fake".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    await viewModel.analyze(url: url)

    XCTAssertEqual(viewModel.step, .review)
    XCTAssertEqual(viewModel.sheets.count, 1)
    XCTAssertTrue(viewModel.canCommit)
  }

  /// Nothing should be importable while rows still need a pillar, because the
  /// server refuses to guess one.
  func testCannotCommitWhenNothingIsImportable() async throws {
    let session = SessionMock()
    let client = makeClient(session)
    let expected = makeAnalysis(
      importable: 0,
      rows: [
        .init(sheetName: "Despesas", row: 5, title: "Continente", amount: 84.2,
              occurredOn: "2026-01-03", sourceCategoryValue: "Supermercado",
              status: .needsCategory),
      ]
    )
    session.handler = { request in
      (try JSONEncoder.stockPlanShared.encode(expected), try self.ok(request))
    }

    let viewModel = SpreadsheetImportViewModel(client: client)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("budget2.xlsx")
    try Data("fake".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    await viewModel.analyze(url: url)

    XCTAssertFalse(viewModel.canCommit)
    XCTAssertEqual(viewModel.rowsNeedingCategory, 1)
  }

  func testUnreadableFileSurfacesErrorAndStaysOnPicker() async throws {
    let session = SessionMock()
    let viewModel = SpreadsheetImportViewModel(client: makeClient(session))
    let missing = FileManager.default.temporaryDirectory
      .appendingPathComponent("does-not-exist-\(UUID().uuidString).xlsx")

    await viewModel.analyze(url: missing)

    XCTAssertEqual(viewModel.step, .pick)
    XCTAssertNotNil(viewModel.errorMessage)
  }

  /// Cancelling should release the server-side session rather than leave an
  /// encrypted copy of the user's finances sitting until it expires.
  func testCancelDiscardsServerSession() async throws {
    let session = SessionMock()
    let client = makeClient(session)
    let expected = makeAnalysis()
    session.handler = { request in
      (try JSONEncoder.stockPlanShared.encode(expected), try self.ok(request))
    }

    let viewModel = SpreadsheetImportViewModel(client: client)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("budget3.xlsx")
    try Data("fake".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    await viewModel.analyze(url: url)

    await viewModel.cancel()

    let deletes = session.requests.filter { $0.httpMethod == "DELETE" }
    XCTAssertEqual(deletes.count, 1)
    XCTAssertEqual(deletes.first?.url?.path, "/v1/expenses/import/spreadsheet/session-1")
  }
}
