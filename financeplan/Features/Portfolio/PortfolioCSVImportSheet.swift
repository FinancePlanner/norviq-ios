import Combine
import PostHog
import StockPlanShared
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct PortfolioCSVImportSheet: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var viewModel: CsvImportFlowViewModel
  @State private var isImporterPresented = false

  let onImportCompleted: @MainActor () async -> Void

  init(
    portfolioListId: String?,
    lockedProvider: String,
    onImportCompleted: @escaping @MainActor () async -> Void
  ) {
    _viewModel = StateObject(
      wrappedValue: CsvImportFlowViewModel(portfolioListId: portfolioListId, lockedProvider: lockedProvider)
    )
    self.onImportCompleted = onImportCompleted
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          CSVImportFormatHint()
        }

        Section("CSV File") {
          Button {
            isImporterPresented = true
          } label: {
            Text(viewModel.selectedFileName ?? "Select CSV File")
          }
          .accessibilityIdentifier("portfolioCSVImport.selectFile")

          if let selectedFileName = viewModel.selectedFileName {
            Text(selectedFileName)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }

          if viewModel.isPreviewing {
            ProgressView("Parsing CSV preview...")
          }
        }

        if let preview = viewModel.previewResponse {
          Section("Preview") {
            Text("\(preview.items.count) parsed row(s) • \(preview.errors.count) issue(s)")
              .foregroundStyle(.secondary)

            ForEach(preview.items, id: \.line) { item in
              VStack(alignment: .leading, spacing: 4) {
                Text(item.symbol)
                  .font(.headline)
                Text("Line \(item.line)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text("Shares: \(item.shares?.formatted(.number.precision(.fractionLength(0...6))) ?? "-") • Buy price: \(item.buyPrice?.formatted(.number.precision(.fractionLength(0...6))) ?? "-")")
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
                if let replaceNote = viewModel.replaceNote(for: item) {
                  Text(replaceNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                if let buyDate = item.buyDate, !buyDate.isEmpty {
                  Text("Buy date: \(buyDate)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                if let notes = item.notes, !notes.isEmpty {
                  Text("Notes: \(notes)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                }
              }
            }
          }
        }

        if viewModel.showsReplaceToggle {
          mergeConfirmationSection
        }

        if let preview = viewModel.previewResponse, !preview.errors.isEmpty {
          Section("Preview Errors") {
            ForEach(preview.errors, id: \.line) { error in
              VStack(alignment: .leading, spacing: 4) {
                Text("Line \(error.line)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text(error.message)
                  .font(.subheadline)
              }
            }
          }
        }

        if let result = viewModel.commitResponse {
          Section("Import Result") {
            Text("Inserted: \(result.inserted.count) • Updated: \(result.updated.count) • Imported lots: \(result.importedLotsCount) • Errors: \(result.errors.count)")

            if !result.errors.isEmpty {
              ForEach(result.errors, id: \.line) { error in
                VStack(alignment: .leading, spacing: 4) {
                  Text("Line \(error.line)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Text(error.message)
                    .font(.subheadline)
                }
              }
            }
          }
        }

        if let errorMessage = viewModel.errorMessage {
          Section {
            Text(errorMessage)
              .foregroundStyle(AppTheme.Colors.danger)
          }
        }
      }
      .navigationTitle("Import CSV")
      .accessibilityIdentifier("portfolioCSVImportSheet")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            dismiss()
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button {
            Task {
              let didImport = await viewModel.commitImport()
              if didImport {
                // PostHog: Track successful CSV import
                let insertedCount = viewModel.commitResponse?.inserted.count ?? 0
                let updatedCount = viewModel.commitResponse?.updated.count ?? 0
                PostHogSDK.shared.capture("portfolio_csv_imported", properties: [
                  "inserted_count": insertedCount,
                  "updated_count": updatedCount,
                ])
                await onImportCompleted()
              }
            }
          } label: {
            if viewModel.isImporting {
              ProgressView()
            } else {
              Text("Import")
            }
          }
          .disabled(!viewModel.canImport)
          .accessibilityIdentifier("portfolioCSVImport.commit")
        }
      }
      .fileImporter(
        isPresented: $isImporterPresented,
        allowedContentTypes: [UTType.commaSeparatedText, .plainText],
        allowsMultipleSelection: false
      ) { result in
        do {
          let urls = try result.get()
          guard let url = urls.first else { return }
          Task {
            await viewModel.loadCSV(from: url)
          }
        } catch {
          viewModel.errorMessage = "Failed to read CSV: \(error.localizedDescription)"
        }
      }
    }
  }

  /// Same wording as the screenshot import: importing over a holding the user
  /// added by hand replaces it, so it is named before it happens.
  private var mergeConfirmationSection: some View {
    Section {
      Toggle(isOn: $viewModel.replaceExisting) {
        Text("Replace positions I already hold")
      }
      .accessibilityIdentifier("portfolioCSVImport.replaceExisting")
    } header: {
      Text("Already in your portfolio")
    } footer: {
      if viewModel.conflictingSymbols.isEmpty {
        Text("Some of these holdings already exist and were not created by this import. Turning this on replaces them with the imported ones. Leave it off and the import stops instead of listing the same symbol twice.")
      } else {
        Text(
          """
          You already hold \(viewModel.conflictingSymbols.joined(separator: ", ")) from \
          outside this import. Turning this on replaces those positions with the imported \
          ones. Leave it off and the import stops instead of listing the same symbol twice.
          """
        )
      }
    }
  }
}
