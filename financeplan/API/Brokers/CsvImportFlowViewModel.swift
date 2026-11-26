import Combine
import Factory
import Foundation
import StockPlanShared

@MainActor
final class CsvImportFlowViewModel: ObservableObject {
  @Published private(set) var connections: [BrokerConnectionResponse] = []
  @Published private(set) var providerOptions: [String] = CsvImportFlowViewModel.fallbackProviders
  @Published var selectedProvider: String = "generic"
  @Published private(set) var selectedFileName: String?
  @Published private(set) var previewResponse: CsvImportPreviewResponse?
  @Published private(set) var commitResponse: CsvImportCommitResponse?
  @Published var errorMessage: String?
  @Published private(set) var isLoadingProviders = false
  @Published private(set) var isPreviewing = false
  @Published private(set) var isImporting = false
  @Published private(set) var isDisconnectingBroker = false
  @Published private(set) var brokerStatusMessage: String?

  private let brokerService: any BrokerServicing
  private let portfolioListId: String?
  private var csvData: Data?
  private var hasLoadedProviders = false
  private static let fallbackProviders = ["generic", "ibkr", "trading212", "degiro", "revolut"]

  init(
    brokerService: any BrokerServicing = Container.shared.brokerService(),
    portfolioListId: String? = nil
  ) {
    self.brokerService = brokerService
    self.portfolioListId = portfolioListId
  }

  var availableProviders: [String] {
    providerOptions
  }

  var canImport: Bool {
    csvData != nil &&
      (previewResponse?.items.isEmpty == false) &&
      !isPreviewing &&
      !isImporting
  }

  var ibkrConnection: BrokerConnectionResponse? {
    connections.first { $0.provider.lowercased() == "ibkr" }
  }

  /// The IBKR card is a notice for every status, including no connection at
  /// all: the Web Service feed is retired and imports go through screenshots.
  var ibkrNotice: IBKRImportNotice { .standard }

  /// Disconnect only makes sense while there is something live to remove.
  var canDisconnectIBKR: Bool {
    guard let status = ibkrConnection?.status.lowercased() else { return false }
    return status == "connected" || status == "error"
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
      self.connections = connections
      applyProviders(connections.map(\.provider))
      errorMessage = nil
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      connections = []
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

    guard let previewResponse, !previewResponse.items.isEmpty else {
      errorMessage = "No valid rows to import."
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
      let importedRowCount = response.inserted.count + response.updated.count + response.importedLotsCount
      if !response.errors.isEmpty {
        return false
      }
      if importedRowCount == 0 {
        errorMessage = "No rows were imported."
        return false
      }
      return true
    } catch {
      commitResponse = nil
      errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      return false
    }
  }

  @discardableResult
  func disconnectIBKRConnection() async -> Bool {
    guard !isDisconnectingBroker else { return false }
    isDisconnectingBroker = true
    errorMessage = nil
    brokerStatusMessage = nil
    defer { isDisconnectingBroker = false }

    do {
      let connection = try await brokerService.disconnectIBKR()
      brokerStatusMessage = String(localized: "\(connection.provider.uppercased()) disconnected.")
      await loadProviders(force: true)
      return true
    } catch {
      brokerStatusMessage = nil
      errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      return false
    }
  }

  private func applyProviders(_ providers: [String]) {
    let normalized = providers
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .filter { !$0.isEmpty }

    providerOptions = mergeProviders(with: normalized)
    let currentSelection = selectedProvider.lowercased()
    selectedProvider = providerOptions.contains(currentSelection) ? currentSelection : (providerOptions.first ?? "generic")
  }

  private func mergeProviders(with providers: [String]) -> [String] {
    var merged = [String]()
    (Self.fallbackProviders + providers).forEach { provider in
      if merged.contains(provider) { return }
      merged.append(provider)
    }
    return merged
  }
}

/// Copy for the Connected Accounts IBKR card. Identical to the shipped web
/// app's "Import IBKR holdings" notice.
struct IBKRImportNotice: Equatable {
  let title: String
  let body: String
  let buttonTitle: String

  static let standard = IBKRImportNotice(
    title: String(localized: "Import IBKR holdings"),
    body: String(localized: "Screenshot your positions in the IBKR app or Client Portal and import them from your portfolio. Statement import with full trade history is coming next."),
    buttonTitle: String(localized: "Import from broker")
  )
}
