import Combine
import Factory
import Foundation
import StockPlanShared

@MainActor
final class CsvImportFlowViewModel: ObservableObject {
  @Published private(set) var connections: [BrokerConnectionResponse] = []
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

  init(
    brokerService: any BrokerServicing = Container.shared.brokerService(),
    portfolioListId: String? = nil,
    lockedProvider: String = BrokerImportCatalog.csvProvider
  ) {
    self.brokerService = brokerService
    self.portfolioListId = portfolioListId
    self.lockedProvider = lockedProvider
  }

  /// The provider preview and commit send. Always fixed by the caller (the
  /// broker picker uses `generic`), so the user cannot relabel the import.
  private let lockedProvider: String
  private var effectiveProvider: String { lockedProvider }

  /// Whether the user chose to replace holdings the import does not own.
  /// Sent as `confirmMergeExisting`; without it the backend answers 409.
  @Published var replaceExisting = false

  /// Symbols already held from somewhere this import will not replace on its
  /// own (typed by hand, or imported from another broker).
  var conflictingSymbols: [String] {
    var seen = Set<String>()
    return (previewResponse?.items ?? [])
      .filter { $0.existingPositionKind != .none && !$0.willReplaceExistingImport }
      .map { $0.symbol.trimmingCharacters(in: .whitespaces).uppercased() }
      .filter { seen.insert($0).inserted }
  }

  /// True once the backend refused a commit for a collision the preview did
  /// not flag, so the toggle must be offered.
  @Published private(set) var didHitMergeConflict = false

  var showsReplaceToggle: Bool {
    !conflictingSymbols.isEmpty || didHitMergeConflict
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

  enum IBKRBadge: Equatable {
    case connected, needsAttention, notConnected
  }

  /// Status chip for the IBKR card; nil until there is a connection row.
  /// Independent of Disconnect gating: `error` is not "connected".
  var ibkrBadge: IBKRBadge? {
    guard let status = ibkrConnection?.status.lowercased() else { return nil }
    switch status {
    case "connected": return .connected
    case "error": return .needsAttention
    default: return .notConnected
    }
  }

  /// The connection's own explanation, shown under an `error` row.
  var ibkrErrorDetail: String? {
    guard ibkrConnection?.status.lowercased() == "error" else { return nil }
    let detail = ibkrConnection?.statusDetail?.trimmingCharacters(in: .whitespacesAndNewlines)
    return (detail?.isEmpty == false) ? detail : nil
  }

  /// Disconnect only makes sense while there is something live to remove.
  var canDisconnectIBKR: Bool {
    guard let status = ibkrConnection?.status.lowercased() else { return false }
    return status == "connected" || status == "error"
  }

  /// Row note when committing would replace holdings the user already has.
  /// `existingPositionKind == .none` means no existing position.
  func replaceNote(for item: CsvImportPreviewItem) -> String? {
    guard item.willReplaceExistingImport || item.existingPositionKind != .none else { return nil }
    return BrokerImportCatalog.csvReplaceNote(symbol: item.symbol)
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
      errorMessage = nil
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      connections = []
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
      replaceExisting = false
      didHitMergeConflict = false
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
        provider: effectiveProvider,
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
        provider: effectiveProvider,
        portfolioListId: portfolioListId,
        csvData: csvData,
        confirmMergeExisting: replaceExisting
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
      // A 409 is the backend asking for confirmation: keep the preview rows,
      // show the toggle on, and let the user retry.
      if (error as? BrokerHTTPClient.Error)?.isConflict == true {
        didHitMergeConflict = true
        replaceExisting = true
      }
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
