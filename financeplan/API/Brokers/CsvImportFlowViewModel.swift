import Combine
import Factory
import Foundation
import StockPlanShared

@MainActor
final class CsvImportFlowViewModel: ObservableObject {
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
  private let portfolioListId: String?
  private var csvData: Data?
  private var hasLoadedProviders = false

  init(
    brokerService: any BrokerServicing = Container.shared.brokerService(),
    portfolioListId: String? = nil
  ) {
    self.brokerService = brokerService
    self.portfolioListId = portfolioListId
  }

  var availableProviders: [String] {
    providerOptions.isEmpty ? ["ibkr"] : providerOptions
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
      applyProviders(connections.map(\.provider))
      errorMessage = nil
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
        portfolioListId: portfolioListId,
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
        portfolioListId: portfolioListId,
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
    let normalized = Array(
      Set(
        providers
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
          .filter { !$0.isEmpty }
      )
    ).sorted()

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
