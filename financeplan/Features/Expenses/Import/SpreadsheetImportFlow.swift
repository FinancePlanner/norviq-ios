import StockPlanShared
import SwiftUI
import UniformTypeIdentifiers

/// Upload an .xlsx, check what it found, import.
///
/// The review step is the point of the feature, not a formality: the server
/// deliberately refuses to guess a pillar, so nothing imports until the user
/// has said where their categories belong.
struct SpreadsheetImportFlow: View {
  @StateObject private var viewModel = SpreadsheetImportViewModel()
  @Environment(\.dismiss) private var dismiss

  /// Called after a successful import so the planner can reload.
  var onImported: () -> Void = {}

  var body: some View {
    NavigationStack {
      Group {
        switch viewModel.step {
        case .pick:
          SpreadsheetImportPickView(viewModel: viewModel)
        case .analyzing:
          SpreadsheetImportProgressView(
            title: "Reading your spreadsheet",
            detail: "Working out which columns are which."
          )
        case .review:
          SpreadsheetImportReviewView(viewModel: viewModel)
        case .committing:
          SpreadsheetImportProgressView(
            title: "Importing",
            detail: "Adding your expenses."
          )
        case .summary:
          SpreadsheetImportSummaryView(viewModel: viewModel) {
            onImported()
            dismiss()
          }
        }
      }
      .id(viewModel.step)
      .navigationTitle("Import spreadsheet")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            Task {
              await viewModel.cancel()
              dismiss()
            }
          }
        }
        if viewModel.step == .review {
          ToolbarItem(placement: .confirmationAction) {
            Button("Import") { Task { await viewModel.commit() } }
              .disabled(!viewModel.canCommit)
          }
        }
      }
      .alert(
        "Import problem",
        isPresented: Binding(
          get: { viewModel.errorMessage != nil },
          set: { if !$0 { viewModel.errorMessage = nil } }
        )
      ) {
        Button("OK", role: .cancel) { viewModel.errorMessage = nil }
      } message: {
        Text(viewModel.errorMessage ?? "")
      }
    }
  }
}

// MARK: - Pick

struct SpreadsheetImportPickView: View {
  @ObservedObject var viewModel: SpreadsheetImportViewModel
  @State private var isPickerPresented = false

  /// `.xlsx` only. Legacy `.xls` is a different binary format the backend
  /// rejects outright, so it isn't offered here either.
  private var allowedTypes: [UTType] {
    [UTType(filenameExtension: "xlsx")].compactMap { $0 }
  }

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      Image(systemName: "tablecells")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
      VStack(spacing: 8) {
        Text("Bring your spreadsheet")
          .font(.title3.weight(.semibold))
        Text("Pick an .xlsx file. We'll work out the columns and show you what we found before anything is added.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(.horizontal)

      Button {
        isPickerPresented = true
      } label: {
        Text("Choose file").frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .padding(.horizontal)

      Spacer()
    }
    .fileImporter(
      isPresented: $isPickerPresented,
      allowedContentTypes: allowedTypes,
      allowsMultipleSelection: false
    ) { result in
      Task { await viewModel.handleFileImport(result.mapError { $0 as any Error }) }
    }
  }
}

// MARK: - Progress

struct SpreadsheetImportProgressView: View {
  let title: String
  let detail: String

  var body: some View {
    VStack(spacing: 16) {
      ProgressView()
        .controlSize(.large)
      Text(title).font(.headline)
      Text(detail)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Review

struct SpreadsheetImportReviewView: View {
  @ObservedObject var viewModel: SpreadsheetImportViewModel

  var body: some View {
    Form {
      if !viewModel.warnings.isEmpty {
        Section("Worth checking") {
          ForEach(viewModel.warnings, id: \.self) { warning in
            Label(warning, systemImage: "exclamationmark.triangle")
              .font(.footnote)
          }
        }
      }

      if let preview = viewModel.preview {
        Section("What we found") {
          LabeledContent("Rows", value: "\(preview.totalRows)")
          LabeledContent("Ready to import", value: "\(preview.importableRows)")
          if preview.duplicateRows > 0 {
            LabeledContent("Already in Norviq", value: "\(preview.duplicateRows)")
          }
          if preview.excludedRows > 0 {
            LabeledContent("Excluded", value: "\(preview.excludedRows)")
          }
          if let start = preview.dateRangeStart, let end = preview.dateRangeEnd {
            LabeledContent("Dates", value: "\(start) → \(end)")
          }
        }
      }

      // The server never invents a pillar, so this is what unblocks the import.
      if viewModel.rowsNeedingCategory > 0 {
        Section("Where do these belong?") {
          Text("\(viewModel.rowsNeedingCategory) rows need a pillar before they can be imported.")
            .font(.footnote)
            .foregroundStyle(.secondary)
          ForEach(viewModel.categoryMappings, id: \.sourceValue) { mapping in
            SpreadsheetCategoryRow(mapping: mapping) { pillar in
              viewModel.setPillar(pillar, forSourceValue: mapping.sourceValue)
            }
          }
        }
      }

      if !viewModel.currenciesNeedingRate.isEmpty {
        Section("Exchange rates") {
          Text("These rows are in another currency. Set a rate to include them.")
            .font(.footnote)
            .foregroundStyle(.secondary)
          ForEach(viewModel.currenciesNeedingRate, id: \.self) { currency in
            SpreadsheetExchangeRateRow(currency: currency) { rate in
              viewModel.setExchangeRate(rate, for: currency)
            }
          }
        }
      }

      if let sheet = viewModel.sheets.first(where: { $0.include }) {
        Section("Columns") {
          ForEach(sheet.columns, id: \.letter) { column in
            SpreadsheetColumnRow(column: column) { field in
              viewModel.setRole(field, forColumn: column.letter)
            }
          }
        }
      }

      if let preview = viewModel.preview, !preview.rows.isEmpty {
        Section(preview.truncated ? "First \(preview.rows.count) rows" : "Rows") {
          ForEach(preview.rows, id: \.row) { row in
            SpreadsheetPreviewRowView(
              row: row,
              isExcluded: viewModel.excludedRows.contains(row.row)
            ) {
              viewModel.toggleRow(row.row)
            }
          }
        }
      }
    }
    .overlay(alignment: .top) {
      if viewModel.isPreviewing {
        ProgressView()
          .padding(8)
          .background(.regularMaterial, in: Capsule())
          .padding(.top, 4)
      }
    }
  }
}

struct SpreadsheetCategoryRow: View {
  let mapping: SpreadsheetImportCategoryMapping
  let onSelect: (BudgetPillar) -> Void

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(mapping.sourceValue)
        if let name = mapping.categoryName {
          Text(name).font(.caption).foregroundStyle(.secondary)
        }
      }
      Spacer()
      Menu {
        ForEach(BudgetPillar.allCases, id: \.rawValue) { pillar in
          Button(pillar.rawValue) { onSelect(pillar) }
        }
      } label: {
        Text(mapping.pillar?.rawValue ?? "Choose")
          .font(.subheadline)
          .foregroundStyle(mapping.pillar == nil ? Color.accentColor : .secondary)
      }
    }
  }
}

struct SpreadsheetColumnRow: View {
  let column: SpreadsheetImportColumn
  let onSelect: (SpreadsheetImportField) -> Void

  private static let selectableFields: [SpreadsheetImportField] = [
    .date, .title, .amount, .category, .pillar, .notes, .currency, .ignore,
  ]

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(column.header ?? "Column \(column.letter)")
        if let sample = column.sampleValues.first {
          Text(sample).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
      }
      Spacer()
      Menu {
        ForEach(Self.selectableFields, id: \.rawValue) { field in
          Button(field.rawValue) { onSelect(field) }
        }
      } label: {
        Text(column.field.rawValue).font(.subheadline).foregroundStyle(.secondary)
      }
    }
  }
}

struct SpreadsheetExchangeRateRow: View {
  let currency: String
  let onSet: (Double) -> Void
  @State private var text = ""

  var body: some View {
    HStack {
      Text(currency)
      Spacer()
      TextField("Rate", text: $text)
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .frame(width: 100)
        .onSubmit { commit() }
      Button("Set") { commit() }
        .font(.caption)
        .disabled(Double(text.replacingOccurrences(of: ",", with: ".")) == nil)
    }
  }

  private func commit() {
    guard let rate = Double(text.replacingOccurrences(of: ",", with: ".")), rate > 0 else { return }
    onSet(rate)
  }
}

struct SpreadsheetPreviewRowView: View {
  let row: SpreadsheetImportPreviewRow
  let isExcluded: Bool
  let onToggle: () -> Void

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(row.title ?? "Row \(row.row)")
          .strikethrough(isExcluded || row.status == .aggregateRow)
        HStack(spacing: 6) {
          if let date = row.occurredOn {
            Text(date).font(.caption).foregroundStyle(.secondary)
          }
          if row.status != .ok {
            Text(statusLabel)
              .font(.caption2)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.secondary.opacity(0.15), in: Capsule())
          }
        }
      }
      Spacer()
      if let amount = row.amount {
        Text(amount, format: .number.precision(.fractionLength(2)))
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(row.status == .ok ? .primary : .secondary)
      }
      Button {
        onToggle()
      } label: {
        Image(systemName: isExcluded ? "circle" : "checkmark.circle.fill")
      }
      .buttonStyle(.plain)
    }
  }

  private var statusLabel: String {
    switch row.status {
    case .ok: "OK"
    case .duplicateInFile: "Repeat"
    case .duplicateExisting: "Already added"
    case .invalidDate: "No date"
    case .invalidAmount: "No amount"
    case .missingTitle: "No description"
    case .needsCategory: "Needs pillar"
    case .needsExchangeRate: "Needs rate"
    case .aggregateRow: "Total"
    case .skippedByUser: "Skipped"
    case .unknown: "Unknown"
    }
  }
}

// MARK: - Summary

struct SpreadsheetImportSummaryView: View {
  @ObservedObject var viewModel: SpreadsheetImportViewModel
  let onDone: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      Spacer()
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 48))
        .foregroundStyle(.green)
      if let result = viewModel.commitResult {
        Text("\(result.imported) expenses imported")
          .font(.title3.weight(.semibold))
        VStack(spacing: 4) {
          if result.skipped > 0 {
            Text("\(result.skipped) skipped").foregroundStyle(.secondary)
          }
          if result.failed > 0 {
            Text("\(result.failed) failed").foregroundStyle(.secondary)
          }
          if !result.createdCategories.isEmpty {
            Text("New categories: \(result.createdCategories.joined(separator: ", "))")
              .font(.footnote)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
        }
        .font(.subheadline)
      }
      Spacer()
      Button {
        onDone()
      } label: {
        Text("Done").frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .padding(.horizontal)
    }
    .padding()
  }
}
