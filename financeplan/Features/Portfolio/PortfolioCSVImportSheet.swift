import Combine
import Factory
import StockPlanShared
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PortfolioCSVImportViewModel: ObservableObject {
  @Published private(set) var providerOptions: [String] = []
  @Published var selectedProvider: String = "ibkr"
  @Published private(set) var selectedFileName: String?
  @Published private(set) var previewResponse: CsvImportPreviewResponse?
  @Published private(set) var commitResponse: CsvImportCommitResponse?
  @Published var errorMessage: String?
  @Published private(set) var isLoadingProviders = false
  @Published private(set) var isPreviewing = false
  @Published private(set) var isImporting = false

  private let brokerService: any BrokerServicing
  private var csvData: Data?
  private var hasLoadedProviders = false

  init(brokerService: any BrokerServicing = Container.shared.brokerService()) {
    self.brokerService = brokerService
  }

  var availableProviders: [String] {
    if providerOptions.isEmpty {
      return ["ibkr"]
    }
    return providerOptions
  }

  var canImport: Bool {
    csvData != nil && previewResponse != nil && !isPreviewing && !isImporting
  }

  func loadProvidersIfNeeded() async {
    guard !hasLoadedProviders else { return }
    await loadProviders(force: true)
  }

  func loadProviders(force: Bool = false) async {
    guard !isLoadingProviders else { return }
    if !force, hasLoadedProviders { return }

    isLoadingProviders = true
    defer {
      isLoadingProviders = false
      hasLoadedProviders = true
    }

    do {
      let connections = try await brokerService.listConnections()
      applyProviders(connections.map { $0.provider })
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      applyProviders([])
    }
  }

  func loadCSV(from url: URL) async {
    let canAccessSecurityScopedResource = url.startAccessingSecurityScopedResource()
    defer {
      if canAccessSecurityScopedResource {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let rawData = try Data(contentsOf: url)
      guard let csvText = String(data: rawData, encoding: .utf8) else {
        throw CocoaError(.fileReadInapplicableStringEncoding)
      }

      csvData = Data(csvText.utf8)
      selectedFileName = url.lastPathComponent
      previewResponse = nil
      commitResponse = nil
      errorMessage = nil
      await previewCSV()
    } catch {
      errorMessage = "Failed to read CSV: \(error.localizedDescription)"
      csvData = nil
      selectedFileName = nil
      previewResponse = nil
      commitResponse = nil
    }
  }

  func previewCSV() async {
    guard let csvData else {
      errorMessage = "Select a CSV file first."
      previewResponse = nil
      return
    }

    guard !isPreviewing else { return }

    isPreviewing = true
    errorMessage = nil
    defer { isPreviewing = false }

    do {
      let response = try await brokerService.previewCsvImport(
        provider: selectedProvider,
        csvData: csvData
      )
      previewResponse = response
      commitResponse = nil
    } catch {
      previewResponse = nil
      commitResponse = nil
      errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
  }

  @discardableResult
  func commitImport() async -> Bool {
    guard let csvData else {
      errorMessage = "Select a CSV file first."
      return false
    }

    guard !isImporting else { return false }

    isImporting = true
    errorMessage = nil
    defer { isImporting = false }

    do {
      let response = try await brokerService.commitCsvImport(
        provider: selectedProvider,
        csvData: csvData
      )
      commitResponse = response
      return true
    } catch {
      commitResponse = nil
      errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      return false
    }
  }

  private func applyProviders(_ providers: [String]) {
    let normalized = Array(Set(providers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .filter { !$0.isEmpty })).sorted()

    providerOptions = normalized

    if let first = normalized.first {
      if !normalized.contains(selectedProvider.lowercased()) {
        selectedProvider = first
      }
      return
    }

    selectedProvider = "ibkr"
  }
}

@MainActor
struct PortfolioCSVImportSheet: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var viewModel: PortfolioCSVImportViewModel
  @State private var isImporterPresented = false

  let onImportCompleted: @MainActor () async -> Void

  init(onImportCompleted: @escaping @MainActor () async -> Void) {
    _viewModel = StateObject(wrappedValue: PortfolioCSVImportViewModel())
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
                Text("\(item.symbol)")
                  .font(.headline)
                Text("Line \(item.line)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text("Shares: \(item.shares?.formatted(.number.precision(.fractionLength(0...6))) ?? "-") • Buy price: \(item.buyPrice?.formatted(.number.precision(.fractionLength(0...6))) ?? "-")")
                  .font(.caption)
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
