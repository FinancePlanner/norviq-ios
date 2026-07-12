import Combine
import Factory
import Foundation
import OSLog
import PostHog
import StockPlanShared
import SwiftData

private let portfolioViewModelLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
  category: "PortfolioViewModel"
)

struct PortfolioAllocationSlice: Identifiable, Equatable, Sendable {
  let id: String
  let symbol: String
  let value: Double
  /// Percent of total portfolio value (0–100).
  let percentage: Double
}

enum PortfolioTargetAlertDirection: String, CaseIterable, Identifiable {
  case above
  case below

  var id: String { rawValue }

  var title: String {
    switch self {
    case .above: return "Above"
    case .below: return "Below"
    }
  }

  var scenario: String {
    switch self {
    case .above: return "base"
    case .below: return "bear"
    }
  }

  static func fromScenario(_ scenario: String) -> PortfolioTargetAlertDirection {
    scenario.lowercased() == "bear" ? .below : .above
  }
}

@MainActor
final class PortfolioViewModel: ObservableObject {
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var editingStock: StockResponse?
  @Published var isSaving = false
  @Published var isDeletingStock = false
  @Published private(set) var cashBalance: Double = 0
  @Published private(set) var sectorExposure: PortfolioSectorExposureResponse?
  @Published private(set) var portfolioLists: [PortfolioListDTOResponse] = []
  @Published var selectedPortfolioListId: String?
  @Published private(set) var isShowingAllLists: Bool = false
  @Published private(set) var targetAlertsBySymbol: [String: TargetResponse] = [:]
  @Published private(set) var isSavingTargetAlert = false
  @Published private(set) var liveQuotes: [String: QuoteResponse] = [:]

  private let service: StockServicing
  private let marketDataService: MarketDataServicing
  private var localStore: (any PortfolioLocalPersisting)?
  private var hasLoadedOnce = false
  private var isRefreshingLiveQuotes = false
  @Published private(set) var nextCursor: String? = nil
  @Published private(set) var isLoadingMore = false

  init(
    service: StockServicing,
    marketDataService: MarketDataServicing,
    localStore: (any PortfolioLocalPersisting)? = nil
  ) {
    self.service = service
    self.marketDataService = marketDataService
    self.localStore = localStore
  }

  convenience init() {
    self.init(
      service: Container.shared.stockService(),
      marketDataService: Container.shared.marketDataService()
    )
  }

  convenience init(service: StockServicing, localStore: (any PortfolioLocalPersisting)? = nil) {
    self.init(service: service, marketDataService: Container.shared.marketDataService(), localStore: localStore)
  }

  func setModelContext(_ context: ModelContext) {
    self.localStore = SwiftDataPortfolioLocalStore(context: context)
  }

  func load(force: Bool = false) async {
    if !force, hasLoadedOnce { return }
    guard !isLoading else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      nextCursor = nil  // reset pagination state on load
      let lists = try await service.fetchPortfolioLists()
      portfolioLists = lists
      if !isShowingAllLists &&
          (selectedPortfolioListId == nil || !lists.contains(where: { $0.id == selectedPortfolioListId })) {
        selectedPortfolioListId = lists.first?.id
      }

      async let stocksTask = service.fetchPortfolio(portfolioListId: selectedPortfolioListId, limit: 50)
      async let summaryTask = service.fetchPortfolioSummary(portfolioListId: selectedPortfolioListId)
      async let targetsTask = service.fetchTargets(symbol: nil)
      let sectorExposureTask = Task {
        await self.fetchPortfolioSectorExposureSafely(portfolioListId: selectedPortfolioListId)
      }
      let (stocksResult, summary, targets) = try await (
        stocksTask,
        summaryTask,
        targetsTask
      )
      let (remoteStocks, fetchedNextCursor) = stocksResult
      await syncWithSwiftData(remoteStocks, listId: selectedPortfolioListId)
      nextCursor = fetchedNextCursor
      cashBalance = extractCashBalance(from: summary)
      self.sectorExposure = await sectorExposureTask.value
      targetAlertsBySymbol = Self.makeTargetAlertsBySymbol(targets)

      hasLoadedOnce = true
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load portfolio."
    }
  }

  /// Refresh only the live market quotes for currently known symbols (cheap poll for "live" feel).
  func refreshLiveQuotes() async {
    guard !isRefreshingLiveQuotes else { return }
    let symbols = liveQuotes.keys.isEmpty ? [] : Array(liveQuotes.keys)
    // If no prior quotes, we can't easily know symbols without full load; caller should load first.
    guard !symbols.isEmpty else { return }
    isRefreshingLiveQuotes = true
    defer { isRefreshingLiveQuotes = false }

    do {
      let batch = try await marketDataService.fetchQuoteBatch(symbols: symbols)
      for q in batch.quotes {
        liveQuotes[q.symbol.uppercased()] = q
      }
    } catch {
      portfolioViewModelLogger.warning("refreshLiveQuotes failed: \(error.localizedDescription)")
    }
  }

  private func syncWithSwiftData(_ remoteStocks: [StockResponse], listId: String?) async {
    guard let localStore else { return }

    do {
      try localStore.reconcile(with: remoteStocks, in: listId)
    } catch {
      portfolioViewModelLogger.error(
        "SwiftData portfolio sync failed: \(error.localizedDescription, privacy: .public)"
      )
      errorMessage = "Couldn't update your cached portfolio. Pull to refresh to try again."
    }
  }

  func loadMoreIfAvailable() async {
    guard !isLoadingMore, let cursor = nextCursor else { return }
    isLoadingMore = true
    defer { isLoadingMore = false }
    do {
      let (items, newCursor) = try await service.fetchPortfolio(portfolioListId: selectedPortfolioListId, cursor: cursor, limit: 50)
      if let localStore {
        for item in items {
          try localStore.upsert(item, in: selectedPortfolioListId)
        }
      }
      nextCursor = newCursor
    } catch {
      portfolioViewModelLogger.error("Load more failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  @discardableResult
  func delete(id: String) async -> Bool {
    guard !isDeletingStock else { return false }
    isDeletingStock = true
    errorMessage = nil
    defer { isDeletingStock = false }

    do {
      try await service.delete(id: id)

      try localStore?.delete(id: id)

      if editingStock?.id == id {
        editingStock = nil
      }
      await refreshPortfolioSummary()
      NotificationCenter.default.post(name: .portfolioDataDidChange, object: nil)
      return true
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to delete stock."
      return false
    }
  }

  func beginEdit(_ stock: StockResponse) {
    editingStock = stock
  }

  func saveEdit(_ updated: StockResponse) async -> Bool {
    guard !isSaving else { return false }
    isSaving = true
    defer { isSaving = false }

    do {
      let saved = try await service.updateStock(
        updated,
        portfolioListId: selectedPortfolioListId
      )

      try localStore?.upsert(saved, in: selectedPortfolioListId)

      editingStock = nil
      await refreshPortfolioSummary()
      NotificationCenter.default.post(name: .portfolioDataDidChange, object: nil)
      return true
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to update stock."
      return false
    }
  }

  func saveNewPosition(_ draft: AddPositionDraft) async -> String? {
    guard !isSaving else { return "Already saving." }

    let symbol = draft.symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard !symbol.isEmpty,
      let shares = Double(draft.shares),
      let buyPrice = Double(draft.buyPrice)
    else {
      return "Enter valid symbol, shares, and buy price."
    }

    isSaving = true
    defer { isSaving = false }

    do {
      let saved = try await service.create(
        stock: StockRequest(
          symbol: symbol,
          shares: shares,
          buyPrice: buyPrice,
          buyDate: DateFormatter.yyyyMMdd.string(from: draft.buyDate),
          notes: draft.notes.isEmpty ? nil : draft.notes,
          category: draft.category
        ),
        portfolioListId: selectedPortfolioListId
      )

      try localStore?.upsert(saved, in: selectedPortfolioListId)

      await refreshPortfolioSummary()
      NotificationCenter.default.post(name: .portfolioDataDidChange, object: nil)
      return nil
    } catch {
      let message = (error as? LocalizedError)?.errorDescription ?? "Failed to create stock."
      errorMessage = message
      return message
    }
  }

  func targetAlert(for symbol: String) -> TargetResponse? {
    targetAlertsBySymbol[Self.normalizedSymbol(symbol)]
  }

  func saveTargetAlert(
    symbol: String,
    price: Double,
    direction: PortfolioTargetAlertDirection
  ) async -> String? {
    let normalizedSymbol = Self.normalizedSymbol(symbol)
    guard !normalizedSymbol.isEmpty else { return "Symbol is required." }
    guard price > 0 else { return "Enter a target price above 0." }
    guard !isSavingTargetAlert else { return "Already saving alert." }

    isSavingTargetAlert = true
    defer { isSavingTargetAlert = false }

    do {
      if let existing = targetAlertsBySymbol[normalizedSymbol] {
        try await service.deleteTarget(id: existing.id)
      }

      let created = try await service.createTarget(
        TargetRequest(
          symbol: normalizedSymbol,
          scenario: direction.scenario,
          targetPrice: price,
          targetDate: nil,
          rationale: "Portfolio alert for \(normalizedSymbol)"
        )
      )
      targetAlertsBySymbol[normalizedSymbol] = created
      // PostHog: Track price target alert set
      PostHogSDK.shared.capture("target_alert_set", properties: [
        "symbol": normalizedSymbol,
        "direction": direction.rawValue,
      ])
      return nil
    } catch {
      let message = (error as? LocalizedError)?.errorDescription ?? "Failed to save price alert."
      errorMessage = message
      return message
    }
  }

  func deleteTargetAlert(symbol: String) async -> String? {
    let normalizedSymbol = Self.normalizedSymbol(symbol)
    guard let existing = targetAlertsBySymbol[normalizedSymbol] else { return nil }
    guard !isSavingTargetAlert else { return "Already saving alert." }

    isSavingTargetAlert = true
    defer { isSavingTargetAlert = false }

    do {
      try await service.deleteTarget(id: existing.id)
      targetAlertsBySymbol.removeValue(forKey: normalizedSymbol)
      return nil
    } catch {
      let message = (error as? LocalizedError)?.errorDescription ?? "Failed to remove price alert."
      errorMessage = message
      return message
    }
  }

  private func refreshPortfolioSummary() async {
    do {
      async let summaryTask = service.fetchPortfolioSummary(portfolioListId: selectedPortfolioListId)
      let sectorExposureTask = Task { await fetchPortfolioSectorExposureSafely(portfolioListId: selectedPortfolioListId) }
      let summary = try await summaryTask
      let sectorExposure = await sectorExposureTask.value
      cashBalance = extractCashBalance(from: summary)
      self.sectorExposure = sectorExposure
    } catch {
      portfolioViewModelLogger.error("Failed to refresh portfolio summary: \(error.localizedDescription, privacy: .public)")
    }
  }

  func selectPortfolioList(_ listId: String) async {
    isShowingAllLists = false
    guard selectedPortfolioListId != listId else { return }
    selectedPortfolioListId = listId
    hasLoadedOnce = false
    await load(force: true)
  }

  func selectAllLists() async {
    guard !isShowingAllLists else { return }
    isShowingAllLists = true
    selectedPortfolioListId = nil
    hasLoadedOnce = false
    await load(force: true)
  }

  func createPortfolioList(name: String) async -> String? {
    let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return "List name is required." }
    do {
      let created = try await service.createPortfolioList(name: normalized)
      selectedPortfolioListId = created.id
      hasLoadedOnce = false
      await load(force: true)
      // PostHog: Track portfolio list created
      PostHogSDK.shared.capture("portfolio_list_created", properties: [
        "name": normalized,
      ])
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  func renamePortfolioList(id: String, name: String) async -> String? {
    let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return "List name is required." }
    do {
      _ = try await service.updatePortfolioList(id: id, name: normalized)
      hasLoadedOnce = false
      await load(force: true)
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  func deletePortfolioList(id: String) async -> String? {
    do {
      try await service.deletePortfolioList(id: id)
      if selectedPortfolioListId == id {
        selectedPortfolioListId = nil
      }
      hasLoadedOnce = false
      await load(force: true)
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  private func extractCashBalance(from summary: PortfolioSummaryResponse) -> Double {
    let reflected = Mirror(reflecting: summary)
      .children
      .first(where: { $0.label == "cashBalance" })?
      .value as? Double
    let allocationCash = summary.allocation
      .first(where: { $0.symbol.uppercased() == "CASH" })?
      .value ?? 0

    if let reflected, reflected > 0 {
      return reflected
    }
    if allocationCash > 0 {
      return allocationCash
    }
    return max(0, reflected ?? 0)
  }

  private static func normalizedSymbol(_ symbol: String) -> String {
    symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
  }

  private static func makeTargetAlertsBySymbol(_ targets: [TargetResponse]) -> [String: TargetResponse] {
    var mapped: [String: TargetResponse] = [:]
    for target in targets {
      let symbol = normalizedSymbol(target.symbol)
      guard !symbol.isEmpty else { continue }
      mapped[symbol] = target
    }
    return mapped
  }

  private func fetchPortfolioSectorExposureSafely(portfolioListId: String?) async -> PortfolioSectorExposureResponse? {
    do {
      return try await service.fetchPortfolioSectorExposure(portfolioListId: portfolioListId)
    } catch {
      if Self.isSectorExposureNotFound(error) {
        portfolioViewModelLogger.warning("Sector exposure endpoint is unavailable (\(error.localizedDescription, privacy: .public))")
      } else {
        portfolioViewModelLogger.warning("Failed to fetch sector exposure: \(error.localizedDescription, privacy: .public)")
      }
      return nil
    }
  }

  private static func isSectorExposureNotFound(_ error: Error) -> Bool {
    if let stockError = error as? StockHTTPClient.Error,
       case .invalidStatus(404) = stockError {
      return true
    }
    if let httpError = error as? any HTTPClientError, httpError.statusCode == 404 {
      return true
    }
    return false
  }
}

@MainActor
protocol PortfolioLocalPersisting {
  func reconcile(with remoteStocks: [StockResponse], in portfolioListId: String?) throws
  func upsert(_ stock: StockResponse, in portfolioListId: String?) throws
  func delete(id: String) throws
}

@MainActor
struct SwiftDataPortfolioLocalStore: PortfolioLocalPersisting {
  private let modelContext: ModelContext
  private let ownerUserId: String

  init(context: ModelContext, ownerUserId: String = LocalCacheScope.currentOwnerUserId) {
    self.modelContext = context
    self.ownerUserId = ownerUserId
  }

  func reconcile(with remoteStocks: [StockResponse], in portfolioListId: String?) throws {
    guard !ownerUserId.isEmpty else { return }
    do {
      try incrementalReconcile(with: remoteStocks, in: portfolioListId)
    } catch {
      // A single bad row must not discard the whole remote batch: rebuild the
      // scope from scratch instead of leaving the stale cache in place.
      modelContext.rollback()
      try rebuildScope(with: remoteStocks, in: portfolioListId)
    }
  }

  private func incrementalReconcile(with remoteStocks: [StockResponse], in portfolioListId: String?) throws {
    let remoteIds = remoteStocks.map(\.id)
    let listId = portfolioListId ?? ""

    try deleteLegacyRows()

    let staleDescriptor: FetchDescriptor<SDPortfolioStock>
    if remoteIds.isEmpty {
      staleDescriptor = FetchDescriptor<SDPortfolioStock>(
        predicate: #Predicate { local in
          local.ownerUserId == ownerUserId && (local.portfolioListId ?? "") == listId
        }
      )
    } else {
      staleDescriptor = FetchDescriptor<SDPortfolioStock>(
        predicate: #Predicate { local in
          local.ownerUserId == ownerUserId && (local.portfolioListId ?? "") == listId && !remoteIds.contains(local.id)
        }
      )
    }

    let staleRows = try modelContext.fetch(staleDescriptor)
    staleRows.forEach(modelContext.delete)

    let existingById: [String: SDPortfolioStock]
    if remoteIds.isEmpty {
      existingById = [:]
    } else {
      let touchedDescriptor = FetchDescriptor<SDPortfolioStock>(
        predicate: #Predicate { local in
          local.ownerUserId == ownerUserId && remoteIds.contains(local.id)
        }
      )
      let touchedRows = try modelContext.fetch(touchedDescriptor)
      existingById = Dictionary(uniqueKeysWithValues: touchedRows.map { ($0.id, $0) })
    }

    for remote in remoteStocks {
      if let local = existingById[remote.id] {
        local.update(from: remote)
        local.ownerUserId = ownerUserId
        local.portfolioListId = listId
      } else {
        let local = SDPortfolioStock(from: remote)
        local.ownerUserId = ownerUserId
        local.portfolioListId = listId
        modelContext.insert(local)
      }
    }

    if modelContext.hasChanges {
      try modelContext.save()
    }
  }

  /// Recovery path: wipe every row that could conflict with the remote batch
  /// (same list scope, or same unique id anywhere) and reinsert fresh.
  private func rebuildScope(with remoteStocks: [StockResponse], in portfolioListId: String?) throws {
    let remoteIds = remoteStocks.map(\.id)
    let listId = portfolioListId ?? ""

    try deleteLegacyRows()

    let conflictingDescriptor = FetchDescriptor<SDPortfolioStock>(
      predicate: #Predicate { local in
        (local.ownerUserId == ownerUserId && (local.portfolioListId ?? "") == listId)
          || remoteIds.contains(local.id)
      }
    )
    let conflictingRows = try modelContext.fetch(conflictingDescriptor)
    conflictingRows.forEach(modelContext.delete)

    for remote in remoteStocks {
      let local = SDPortfolioStock(from: remote)
      local.ownerUserId = ownerUserId
      local.portfolioListId = listId
      modelContext.insert(local)
    }

    if modelContext.hasChanges {
      try modelContext.save()
    }
  }

  func upsert(_ stock: StockResponse, in portfolioListId: String?) throws {
    guard !ownerUserId.isEmpty else { return }
    try deleteLegacyRows()
    let id = stock.id
    let listId = portfolioListId ?? ""
    let descriptor = FetchDescriptor<SDPortfolioStock>(
      predicate: #Predicate { $0.ownerUserId == ownerUserId && $0.id == id }
    )
    if let existing = try modelContext.fetch(descriptor).first {
      existing.update(from: stock)
      existing.ownerUserId = ownerUserId
      existing.portfolioListId = listId
    } else {
      let local = SDPortfolioStock(from: stock)
      local.ownerUserId = ownerUserId
      local.portfolioListId = listId
      modelContext.insert(local)
    }
    if modelContext.hasChanges {
      try modelContext.save()
    }
  }

  func delete(id: String) throws {
    guard !ownerUserId.isEmpty else { return }
    let descriptor = FetchDescriptor<SDPortfolioStock>(
      predicate: #Predicate { $0.ownerUserId == ownerUserId && $0.id == id }
    )
    if let existing = try modelContext.fetch(descriptor).first {
      modelContext.delete(existing)
    }
    if modelContext.hasChanges {
      try modelContext.save()
    }
  }

  private func deleteLegacyRows() throws {
    let descriptor = FetchDescriptor<SDPortfolioStock>(
      predicate: #Predicate { $0.ownerUserId == nil }
    )
    let rows = try modelContext.fetch(descriptor)
    rows.forEach(modelContext.delete)
  }
}
