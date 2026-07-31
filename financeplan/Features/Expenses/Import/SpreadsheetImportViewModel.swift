import Combine
import Factory
import Foundation
import StockPlanShared
import SwiftUI

/// Drives pick -> analyzing -> review -> committing -> summary.
///
/// The server holds the parsed rows, so changing a mapping is a cheap round
/// trip rather than a re-upload. That shapes this type: it keeps the decision
/// locally, debounces re-previews, and never re-sends the file.
@MainActor
final class SpreadsheetImportViewModel: ObservableObject {
  enum Step: Equatable {
    case pick
    case analyzing
    case review
    case committing
    case summary
  }

  @Published private(set) var step: Step = .pick
  @Published private(set) var analysis: SpreadsheetImportAnalysisResponse?
  @Published private(set) var preview: SpreadsheetImportPreview?
  @Published private(set) var commitResult: SpreadsheetImportCommitResponse?
  @Published private(set) var warnings: [String] = []
  @Published private(set) var isPreviewing = false
  @Published var errorMessage: String?
  @Published private(set) var fileName: String?

  /// The user's decisions. Edited in place by the review screen.
  @Published var sheets: [SpreadsheetImportSheet] = []
  @Published var categoryMappings: [SpreadsheetImportCategoryMapping] = []
  @Published var amountSign: SpreadsheetImportAmountSign = .positiveIsExpense
  @Published var dateOrder: String = "dayFirst"
  @Published var exchangeRates: [String: Double] = [:]
  @Published var excludedRows: Set<Int> = []

  private let client: SpreadsheetImportHTTPClient
  private var sessionId: String?
  private var previewTask: Task<Void, Never>?

  init(client: SpreadsheetImportHTTPClient = Container.shared.spreadsheetImportHTTPClient()) {
    self.client = client
  }

  /// Rows still needing a pillar before anything can be imported. The server
  /// refuses to guess one, so this is the review screen's main job.
  var rowsNeedingCategory: Int {
    preview?.rows.filter { $0.status == .needsCategory }.count ?? 0
  }

  var currenciesNeedingRate: [String] {
    guard let preview else { return [] }
    let needing = preview.rows.filter { $0.status == .needsExchangeRate }
    return Array(Set(needing.compactMap(\.currency))).sorted()
  }

  var canCommit: Bool {
    (preview?.importableRows ?? 0) > 0 && step == .review
  }

  // MARK: - Upload

  func handleFileImport(_ result: Result<[URL], any Error>) async {
    switch result {
    case let .success(urls):
      guard let url = urls.first else { return }
      await analyze(url: url)
    case let .failure(error):
      errorMessage = error.localizedDescription
    }
  }

  func analyze(url: URL) async {
    step = .analyzing
    errorMessage = nil

    let data: Data
    do {
      // Files picked from the Files app live outside the sandbox, so access has
      // to be claimed and released around the read.
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      data = try Data(contentsOf: url)
    } catch {
      errorMessage = "We couldn't read that file."
      step = .pick
      return
    }

    fileName = url.lastPathComponent
    do {
      let response = try await client.analyze(fileData: data, filename: url.lastPathComponent)
      apply(analysis: response)
      step = .review
    } catch {
      errorMessage = error.localizedDescription
      step = .pick
    }
  }

  private func apply(analysis response: SpreadsheetImportAnalysisResponse) {
    analysis = response
    sessionId = response.sessionId
    sheets = response.sheets
    categoryMappings = response.categoryMappings
    amountSign = response.amountSign
    dateOrder = response.dateFormat ?? "dayFirst"
    preview = response.preview
    warnings = response.warnings
    fileName = response.fileName
  }

  // MARK: - Review

  /// Re-derives the preview after a change, debounced so dragging through a
  /// picker doesn't fire a request per step.
  func schedulePreviewRefresh() {
    previewTask?.cancel()
    previewTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(400))
      guard !Task.isCancelled else { return }
      await self?.refreshPreview()
    }
  }

  func refreshPreview() async {
    guard let sessionId else { return }
    isPreviewing = true
    defer { isPreviewing = false }
    do {
      let response = try await client.preview(sessionId: sessionId, decision: currentDecision())
      preview = response.preview
      sheets = response.sheets
      categoryMappings = response.categoryMappings
      warnings = response.warnings
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func setPillar(_ pillar: BudgetPillar, forSourceValue sourceValue: String) {
    if let index = categoryMappings.firstIndex(where: { $0.sourceValue == sourceValue }) {
      let existing = categoryMappings[index]
      categoryMappings[index] = .init(
        sourceValue: existing.sourceValue,
        pillar: pillar,
        categoryId: existing.categoryId,
        categoryName: existing.categoryName,
        createCategory: existing.createCategory,
        confidence: 1,
        source: .user
      )
    } else {
      categoryMappings.append(
        .init(sourceValue: sourceValue, pillar: pillar, confidence: 1, source: .user)
      )
    }
    schedulePreviewRefresh()
  }

  func setRole(_ role: SpreadsheetImportField, forColumn letter: String) {
    guard let sheetIndex = sheets.firstIndex(where: { $0.include }) else { return }
    let sheet = sheets[sheetIndex]
    let columns = sheet.columns.map { column -> SpreadsheetImportColumn in
      guard column.letter == letter else { return column }
      return .init(
        letter: column.letter,
        header: column.header,
        detectedType: column.detectedType,
        sampleValues: column.sampleValues,
        field: role,
        confidence: 1,
        source: .user
      )
    }
    sheets[sheetIndex] = .init(
      name: sheet.name, index: sheet.index, rowCount: sheet.rowCount, headerRow: sheet.headerRow,
      dataStartRow: sheet.dataStartRow, dataEndRow: sheet.dataEndRow, include: sheet.include,
      isRecommended: sheet.isRecommended, columns: columns, excludedRows: sheet.excludedRows,
      notes: sheet.notes
    )
    schedulePreviewRefresh()
  }

  func toggleRow(_ row: Int) {
    if excludedRows.contains(row) {
      excludedRows.remove(row)
    } else {
      excludedRows.insert(row)
    }
    schedulePreviewRefresh()
  }

  func setExchangeRate(_ rate: Double, for currency: String) {
    exchangeRates[currency.uppercased()] = rate
    schedulePreviewRefresh()
  }

  // MARK: - Commit

  func commit() async {
    guard let sessionId else { return }
    previewTask?.cancel()
    step = .committing
    errorMessage = nil
    do {
      commitResult = try await client.commit(sessionId: sessionId, decision: currentDecision())
      step = .summary
    } catch {
      errorMessage = error.localizedDescription
      step = .review
    }
  }

  /// Releases the server-side session rather than leaving an encrypted copy of
  /// the user's finances sitting until it expires.
  func cancel() async {
    previewTask?.cancel()
    guard let sessionId else { return }
    await client.discard(sessionId: sessionId)
    self.sessionId = nil
  }

  // MARK: - Decision

  private func currentDecision() -> SpreadsheetImportDecisionRequest {
    let sheetName = sheets.first(where: { $0.include })?.name ?? sheets.first?.name ?? ""
    return SpreadsheetImportDecisionRequest(
      sheets: sheets,
      categoryMappings: categoryMappings,
      rowOverrides: excludedRows.map {
        SpreadsheetImportRowOverride(sheetName: sheetName, row: $0, include: false)
      },
      amountSign: amountSign,
      dateFormat: dateOrder,
      exchangeRates: exchangeRates
    )
  }
}
