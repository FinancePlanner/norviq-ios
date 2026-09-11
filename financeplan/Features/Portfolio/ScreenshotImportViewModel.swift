import Factory
import Foundation
import PhotosUI
import StockPlanShared
import SwiftUI

/// An extracted position as the review UI holds it.
///
/// Numbers are strings on purpose: the user is editing them, a half-typed
/// "12." is a valid intermediate state, and an empty field has to stay
/// distinguishable from zero. Parsing happens once, at commit.
struct ScreenshotImportRow: Identifiable, Equatable {
  let id = UUID()
  var symbol: String
  var shares: String
  var buyPrice: String
  var buyDate: String?
  var isIncluded: Bool = true

  /// Confidence the extractor reported for this row, when it reported one.
  var confidence: Double?
  /// A position already imported from this provider that this row would replace.
  var willReplace: Bool = false
  /// What the user already holds for this symbol, if anything.
  var existingKind: CsvImportExistingPositionKind = .none

  /// Deliberately generous: an unnecessary glance is far cheaper than a wrong
  /// share count landing in someone's portfolio.
  var needsAttention: Bool {
    willReplace || existingKind == .manual || isLowConfidence
  }

  var isLowConfidence: Bool {
    guard let confidence else { return false }
    return confidence < 0.75
  }

  var attentionMessage: String {
    if willReplace { return "Replaces a position previously imported from this broker" }
    if existingKind == .manual { return "You already hold this, added manually" }
    return "Hard to read — check these figures"
  }
}

@MainActor
@Observable
final class ScreenshotImportViewModel {
  static let maxImages = BrokerHTTPClient.maxScreenshotImages

  /// Provider label recorded against imported positions. Screenshots carry no
  /// reliable broker identity, so they are attributed generically rather than
  /// claiming a broker we did not verify.
  private static let provider = "manual"

  var pickedItems: [PhotosPickerItem] = [] {
    didSet { handlePicked(oldValue: oldValue) }
  }

  /// Settable because the review screen edits these in place — correcting a
  /// misread figure is the point of the step.
  var rows: [ScreenshotImportRow] = []
  private(set) var warnings: [String] = []
  private(set) var errorMessage: String?
  private(set) var isExtracting = false
  private(set) var isCommitting = false
  private(set) var didCommit = false
  private(set) var kind: ScreenshotImportKind = .unknown
  private(set) var insertedCount = 0
  private(set) var updatedCount = 0

  private let portfolioListId: String?
  private let brokerService: any BrokerServicing

  init(
    portfolioListId: String?,
    brokerService: any BrokerServicing = Container.shared.brokerService()
  ) {
    self.portfolioListId = portfolioListId
    self.brokerService = brokerService
  }

  var selectedRowCount: Int {
    rows.filter(\.isIncluded).count
  }

  var hasCostBasis: Bool {
    kind == .trades
  }

  var kindLabel: String {
    switch kind {
    case .holdings: return "Holdings list"
    case .trades: return "Trade confirmations"
    case .unknown: return "Unrecognised"
    }
  }

  var commitSummary: String {
    switch (insertedCount, updatedCount) {
    case let (inserted, updated) where inserted > 0 && updated > 0:
      return "Added \(inserted) position(s) and updated \(updated)."
    case let (inserted, _) where inserted > 0:
      return "Added \(inserted) position(s)."
    case let (_, updated) where updated > 0:
      return "Updated \(updated) position(s)."
    default:
      return "Nothing was imported."
    }
  }

  private func handlePicked(oldValue: [PhotosPickerItem]) {
    guard pickedItems != oldValue, !pickedItems.isEmpty else { return }
    Task { await extract(from: pickedItems) }
  }

  private func extract(from items: [PhotosPickerItem]) async {
    isExtracting = true
    errorMessage = nil
    warnings = []
    defer { isExtracting = false }

    var images: [ScreenshotUploadImage] = []
    for item in items.prefix(Self.maxImages) {
      guard
        let data = try? await item.loadTransferable(type: Data.self),
        // Downscale on-device: a raw screenshot is several MB and more pixels
        // buy no accuracy, so this avoids both the size cap and wasted tokens.
        let prepared = UploadImagePreparer.prepare(data)
      else {
        warnings.append("One image could not be read and was skipped.")
        continue
      }
      images.append(prepared)
    }

    guard !images.isEmpty else {
      errorMessage = "None of those images could be read."
      return
    }

    do {
      let response = try await brokerService.previewScreenshotImport(
        provider: Self.provider,
        portfolioListId: portfolioListId,
        images: images
      )
      kind = response.kind
      warnings.append(contentsOf: response.errors.map(\.message))
      rows = response.items.map { item in
        ScreenshotImportRow(
          symbol: item.symbol,
          shares: item.shares.map { Self.format($0) } ?? "",
          buyPrice: item.buyPrice.map { Self.format($0) } ?? "",
          buyDate: item.buyDate,
          confidence: item.confidence,
          willReplace: item.willReplaceExistingImport,
          existingKind: item.existingPositionKind
        )
      }
      if rows.isEmpty, warnings.isEmpty {
        errorMessage = "Nothing could be read from those images."
      }
    } catch {
      errorMessage = (error as? any LocalizedError)?.errorDescription
        ?? "Could not read those screenshots. Try again, or import a CSV instead."
    }
  }

  func commit() async {
    guard !isCommitting else { return }
    isCommitting = true
    errorMessage = nil
    defer { isCommitting = false }

    let items = rows
      .filter { $0.isIncluded && !$0.symbol.trimmingCharacters(in: .whitespaces).isEmpty }
      .enumerated()
      .map { index, row in
        CsvImportPreviewItem(
          line: index,
          symbol: row.symbol.trimmingCharacters(in: .whitespaces).uppercased(),
          shares: Self.parse(row.shares),
          buyPrice: Self.parse(row.buyPrice),
          buyDate: row.buyDate,
          confidence: row.confidence
        )
      }

    guard !items.isEmpty else {
      errorMessage = "No positions selected to import."
      return
    }

    do {
      let response = try await brokerService.commitScreenshotImport(
        ScreenshotImportCommitRequest(
          provider: Self.provider,
          portfolioListId: portfolioListId,
          items: items
        )
      )
      insertedCount = response.inserted.count
      updatedCount = response.updated.count
      warnings = response.errors.map(\.message)
      didCommit = true
    } catch {
      errorMessage = (error as? any LocalizedError)?.errorDescription
        ?? "Import failed. Check the rows and try again."
    }
  }

  /// Accepts a European decimal comma: a row corrected to "1,5" is a change the
  /// user meant to make, and silently dropping it would be worse than reading it.
  private static func parse(_ raw: String) -> Double? {
    let normalized = raw
      .trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: ",", with: ".")
    return normalized.isEmpty ? nil : Double(normalized)
  }

  private static func format(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(value)
  }
}
