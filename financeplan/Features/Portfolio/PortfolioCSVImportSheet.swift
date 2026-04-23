import Combine
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
    onImportCompleted: @escaping @MainActor () async -> Void
  ) {
    _viewModel = StateObject(wrappedValue: CsvImportFlowViewModel(portfolioListId: portfolioListId))
    self.onImportCompleted = onImportCompleted
  }

  var body: some View {
    NavigationStack {
      List {
        Section("Broker") {
          Picker("Provider", selection: $viewModel.selectedProvider) {
            ForEach(viewModel.availableProviders, id: \.self) { provider in
              Text(provider.uppercased()).tag(provider)
            }
          }
          .pickerStyle(.menu)
          .disabled(viewModel.isLoadingProviders)

          if viewModel.isLoadingProviders {
            ProgressView("Loading broker connections...")
          }
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
                  .font(.headline)
              }
            }
          }
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
            Text("Inserted: \(result.inserted.count) • Updated: \(result.updated.count) • Errors: \(result.errors.count)")

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
              .foregroundStyle(.red)
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
      .task {
        await viewModel.loadProvidersIfNeeded()
      }
      .onChange(of: viewModel.selectedProvider) { _, _ in
        guard viewModel.previewResponse != nil else { return }
        Task {
          await viewModel.previewCSV()
        }
      }
    }
  }
}
