import Factory
import Foundation
import PhotosUI
import StockPlanShared
import SwiftUI

/// One expense line awaiting confirmation.
///
/// Amounts are strings because the user is editing them: a half-typed "12."
/// is a valid intermediate state and an empty field must stay distinguishable
/// from zero. Parsing happens once, at commit.
struct ReceiptExpenseLine: Identifiable, Equatable {
  let id = UUID()
  var title: String
  var amount: String
  var pillar: BudgetPillar
  var isIncluded: Bool = true
  /// Stable identity for this line within its receipt, so re-scanning the same
  /// slip dedupes on the server instead of inserting a second copy.
  let externalId: String?
}

/// One scanned receipt and the expenses it produced.
struct ReceiptBatchEntry: Identifiable, Equatable {
  let id = UUID()
  var merchant: String
  var date: String?
  var currency: String?
  var total: Double?
  var lines: [ReceiptExpenseLine]
  var metadata: ExpenseReceiptMetadata?

  /// Set when the receipt listed items whose sum does not match its printed
  /// total. Both figures are shown rather than either being trusted.
  var reconciliationWarning: String?

  /// True when the receipt was read as a single expense because no line items
  /// were legible — worth saying, so an itemised split isn't silently expected.
  var isSingleLine: Bool { lines.count == 1 }

  var includedTotal: Double {
    lines.filter(\.isIncluded).compactMap { Double($0.amount.replacingOccurrences(of: ",", with: ".")) }.reduce(0, +)
  }
}

@MainActor
@Observable
final class ReceiptBatchImportViewModel {
  static let maxImages = ReceiptsHTTPClient.maxBatchImages

  var pickedItems: [PhotosPickerItem] = [] {
    didSet { handlePicked(oldValue: oldValue) }
  }

  var entries: [ReceiptBatchEntry] = []
  private(set) var warnings: [String] = []
  private(set) var errorMessage: String?
  private(set) var isScanning = false
  private(set) var isCommitting = false
  private(set) var didCommit = false
  private(set) var importedCount = 0
  private(set) var skippedCount = 0

  private let client: ReceiptsHTTPClient

  init(client: ReceiptsHTTPClient = Container.shared.receiptsHTTPClient()) {
    self.client = client
  }

  var selectedLineCount: Int {
    entries.reduce(0) { $0 + $1.lines.filter(\.isIncluded).count }
  }

  var commitSummary: String {
    var parts = ["Added \(importedCount) expense(s)."]
    if skippedCount > 0 {
      parts.append("\(skippedCount) already recorded and skipped.")
    }
    return parts.joined(separator: " ")
  }

  private func handlePicked(oldValue: [PhotosPickerItem]) {
    guard pickedItems != oldValue, !pickedItems.isEmpty else { return }
    Task { await scanPicked(pickedItems) }
  }

  private func scanPicked(_ items: [PhotosPickerItem]) async {
    var images: [ScreenshotUploadImage] = []
    for item in items.prefix(Self.maxImages) {
      guard
        let data = try? await item.loadTransferable(type: Data.self),
        let prepared = UploadImagePreparer.prepare(data)
      else {
        warnings.append("One photo could not be read and was skipped.")
        continue
      }
      images.append(prepared)
    }
    await scan(images)
  }

  /// Scans a single freshly-taken photo, appending to whatever is already here
  /// so the user can photograph several receipts one after another.
  func scanCaptured(_ jpeg: Data) async {
    guard entries.count < Self.maxImages else {
      errorMessage = "Scan at most \(Self.maxImages) receipts at a time."
      return
    }
    await scan([ScreenshotUploadImage(data: jpeg, contentType: "image/jpeg")])
  }

  func scan(_ images: [ScreenshotUploadImage]) async {
    guard !images.isEmpty else {
      errorMessage = "None of those photos could be read."
      return
    }
    isScanning = true
    errorMessage = nil
    defer { isScanning = false }

    do {
      let response = try await client.scanBatch(images)
      var unreadable = 0
      for result in response.results {
        guard let draft = result.draft, result.recognized else {
          unreadable += 1
          continue
        }
        entries.append(Self.makeEntry(from: draft))
      }
      if unreadable > 0 {
        warnings.append("\(unreadable) photo(s) could not be read as a receipt.")
      }
      if entries.isEmpty, errorMessage == nil {
        errorMessage = "Nothing could be read from those photos."
      }
    } catch {
      errorMessage = (error as? any LocalizedError)?.errorDescription
        ?? "Could not read those receipts. Try again, or enter the expense manually."
    }
  }

  /// Turns a draft into editable lines.
  ///
  /// Line items become one expense each, but only when they reconcile with the
  /// printed total. When they don't, OCR misread at least one figure, and
  /// splitting on numbers we know are wrong would quietly corrupt the month —
  /// so the receipt falls back to a single expense for the total and says why.
  private static func makeEntry(from draft: ReceiptDraft) -> ReceiptBatchEntry {
    let merchant = draft.merchant?.trimmingCharacters(in: .whitespaces).nilIfBlank
      ?? draft.taxId.map { "Receipt · \($0)" }
      ?? "Receipt"

    let metadata = ExpenseReceiptMetadata(
      source: draft.source == .qr ? .qr : .ocr,
      merchant: draft.merchant,
      taxIdentifier: draft.taxId,
      issuedOn: draft.date,
      currency: draft.currency,
      total: draft.total,
      vatTotal: draft.taxTotal
    )

    let identity = [draft.taxId ?? "", draft.date ?? "", draft.total.map { String($0) } ?? ""]
      .joined(separator: "|")

    let reconciles = draft.lineItemsReconcile
    if !draft.lineItems.isEmpty, reconciles == true {
      let lines = draft.lineItems.enumerated().map { index, item in
        ReceiptExpenseLine(
          title: item.description,
          amount: Self.format(item.amount),
          pillar: .fundamentals,
          externalId: identity.isEmpty ? nil : "\(identity)#\(index)"
        )
      }
      return ReceiptBatchEntry(
        merchant: merchant,
        date: draft.date,
        currency: draft.currency,
        total: draft.total,
        lines: lines,
        metadata: metadata
      )
    }

    var warning: String?
    if !draft.lineItems.isEmpty, reconciles == false {
      let sum = draft.lineItemsSum ?? 0
      let total = draft.total ?? 0
      warning = String(
        format: "Items read add up to %.2f but the receipt says %.2f, so they were not split. Check the total.",
        sum, total
      )
    }

    return ReceiptBatchEntry(
      merchant: merchant,
      date: draft.date,
      currency: draft.currency,
      total: draft.total,
      lines: [
        ReceiptExpenseLine(
          title: merchant,
          amount: draft.total.map(Self.format) ?? "",
          pillar: .fundamentals,
          externalId: identity.isEmpty ? nil : identity
        ),
      ],
      metadata: metadata,
      reconciliationWarning: warning
    )
  }

  func commit() async {
    guard !isCommitting else { return }
    isCommitting = true
    errorMessage = nil
    defer { isCommitting = false }

    var items: [ReceiptImportItem] = []
    for entry in entries {
      for line in entry.lines where line.isIncluded {
        guard
          let amount = Self.parse(line.amount), amount > 0,
          !line.title.trimmingCharacters(in: .whitespaces).isEmpty
        else { continue }

        items.append(
          ReceiptImportItem(
            externalId: line.externalId,
            expense: ExpenseRequest(
              title: line.title.trimmingCharacters(in: .whitespaces),
              amount: amount,
              pillar: line.pillar,
              occurredOn: entry.date ?? Self.today(),
              receiptMetadata: entry.metadata
            )
          )
        )
      }
    }

    guard !items.isEmpty else {
      errorMessage = "No expenses selected to add."
      return
    }

    do {
      let response = try await client.commitReceipts(ReceiptImportCommitRequest(items: items))
      importedCount = response.imported
      skippedCount = response.skipped
      warnings = response.errors.map(\.message)
      didCommit = true
    } catch {
      errorMessage = (error as? any LocalizedError)?.errorDescription
        ?? "Could not add those expenses. Try again."
    }
  }

  /// Accepts a European decimal comma — an edit typed as "1,5" is a correction
  /// the user meant to make, and dropping it silently would be worse.
  private static func parse(_ raw: String) -> Double? {
    let normalized = raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    return normalized.isEmpty ? nil : Double(normalized)
  }

  private static func format(_ value: Double) -> String {
    String(format: "%.2f", value)
  }

  private static func today() -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
  }
}

private extension String {
  var nilIfBlank: String? {
    trimmingCharacters(in: .whitespaces).isEmpty ? nil : self
  }
}
