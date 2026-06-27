import Combine
import Factory
import StockPlanShared
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct WatchlistCSVImportSheet: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var viewModel: WatchlistCSVImportViewModel
  @State private var isImporterPresented = false

  let onImportCompleted: @MainActor () async -> Void

  init(
    watchlistListId: String?,
    listName: String?,
    onImportCompleted: @escaping @MainActor () async -> Void
  ) {
    _viewModel = StateObject(
      wrappedValue: WatchlistCSVImportViewModel(watchlistListId: watchlistListId, listName: listName)
    )
    self.onImportCompleted = onImportCompleted
  }

  var body: some View {
    NavigationStack {
      List {
        if let listName = viewModel.listName {
          Section("Target List") {
            Text(listName)
          }
        }

        Section {
          WatchlistCSVImportFormatHint()
        }

        Section("CSV File") {
          Button {
            isImporterPresented = true
          } label: {
            Text(viewModel.selectedFileName ?? "Select CSV File")
          }

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
            Text("\(preview.items.count) parsed symbol(s) • \(preview.errors.count) issue(s)")
              .foregroundStyle(.secondary)

            ForEach(preview.items, id: \.line) { item in
              VStack(alignment: .leading, spacing: 4) {
                Text(item.symbol)
                  .font(.headline)
                Text("Line \(item.line) • \(item.willUpdateExisting ? "Update" : "Add")")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                if let note = item.note, !note.isEmpty {
                  Text(note)
                    .font(.subheadline)
                }
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
          }
        }

        if let errorMessage = viewModel.errorMessage {
          Section {
            Text(errorMessage)
              .foregroundStyle(.red)
          }
        }
      }
      .navigationTitle("Import Watchlist CSV")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Import") {
            Task {
              let didCommit = await viewModel.commitImport()
              if didCommit {
                await onImportCompleted()
                dismiss()
              }
            }
          }
          .disabled(!viewModel.canCommit)
        }
      }
      .fileImporter(
        isPresented: $isImporterPresented,
        allowedContentTypes: [.commaSeparatedText, .plainText],
        allowsMultipleSelection: false
      ) { result in
        Task {
          await viewModel.handleFileImport(result)
        }
      }
    }
  }
}

@MainActor
final class WatchlistCSVImportViewModel: ObservableObject {
  @Published private(set) var selectedFileName: String?
  @Published private(set) var previewResponse: WatchlistCsvImportPreviewResponse?
  @Published private(set) var commitResponse: WatchlistCsvImportCommitResponse?
  @Published private(set) var isPreviewing = false
  @Published private(set) var isCommitting = false
  @Published var errorMessage: String?

  let listName: String?

  private let watchlistListId: String?
  private let service: StockServicing
  private var csvData: Data?

  var canCommit: Bool {
    guard let previewResponse else { return false }
    return !isCommitting && !previewResponse.items.isEmpty
  }

  init(
    watchlistListId: String?,
    listName: String?,
    service: StockServicing = Container.shared.stockService()
  ) {
    self.watchlistListId = watchlistListId
    self.listName = listName
    self.service = service
  }

  func handleFileImport(_ result: Result<[URL], Error>) async {
    do {
      guard let url = try result.get().first else { return }
      try await loadCSV(from: url)
      await previewCSV()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func commitImport() async -> Bool {
    guard let csvData else {
      errorMessage = "Select a CSV file first."
      return false
    }
    isCommitting = true
    defer { isCommitting = false }

    do {
      commitResponse = try await service.commitWatchlistCsvImport(
        watchlistListId: watchlistListId,
        csvData: csvData
      )
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  private func loadCSV(from url: URL) async throws {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer {
      if didAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    csvData = try Data(contentsOf: url)
    selectedFileName = url.lastPathComponent
    previewResponse = nil
    commitResponse = nil
    errorMessage = nil
  }

  private func previewCSV() async {
    guard let csvData else { return }
    isPreviewing = true
    defer { isPreviewing = false }

    do {
      previewResponse = try await service.previewWatchlistCsvImport(
        watchlistListId: watchlistListId,
        csvData: csvData
      )
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
