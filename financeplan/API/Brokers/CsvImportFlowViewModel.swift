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
  @Published private(set) var isConnectingBroker = false
  @Published private(set) var isSyncingBroker = false
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

  var isIBKRConnected: Bool {
    guard let status = ibkrConnection?.status.lowercased() else { return false }
    return status == "connected" || status == "active"
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
  func connectIBKR() async -> Bool {
    guard !isConnectingBroker else { return false }
    isConnectingBroker = true
    errorMessage = nil
    brokerStatusMessage = nil
    defer { isConnectingBroker = false }

    do {
      _ = try await brokerService.connectIBKR(portfolioListId: portfolioListId)
      brokerStatusMessage = "Connected IBKR."
      await loadProviders(force: true)
      return true
    } catch {
      brokerStatusMessage = nil
      errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      return false
    }
  }

  @discardableResult
  func syncIBKRConnection() async -> Bool {
    guard !isSyncingBroker else { return false }
    isSyncingBroker = true
    errorMessage = nil
    brokerStatusMessage = nil
    defer { isSyncingBroker = false }

    do {
      _ = try await brokerService.syncIBKR()
      brokerStatusMessage = "Sync complete."
      await loadProviders(force: true)
      return true
    } catch {
      brokerStatusMessage = nil
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
      brokerStatusMessage = "\(connection.provider.uppercased()) disconnected."
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
