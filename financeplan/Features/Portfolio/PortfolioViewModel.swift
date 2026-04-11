import Combine
import Factory
import Foundation
import OSLog
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

@MainActor
final class PortfolioViewModel: ObservableObject {
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var editingStock: StockResponse?
  @Published var isSaving = false
  @Published var isDeletingStock = false
  @Published private(set) var cashBalance: Double = 0
  @Published private(set) var portfolioLists: [PortfolioListDTOResponse] = []
  @Published var selectedPortfolioListId: String?
  @Published private(set) var isShowingAllLists: Bool = false

  private let service: StockServicing
  private var localStore: (any PortfolioLocalPersisting)?
  private var hasLoadedOnce = false

  init(
    service: StockServicing,
    localStore: (any PortfolioLocalPersisting)? = nil
  ) {
    self.service = service
    self.localStore = localStore
  }

  convenience init() {
    self.init(service: Container.shared.stockService())
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
      let lists = try await service.fetchPortfolioLists()
      portfolioLists = lists
      if !isShowingAllLists &&
          (selectedPortfolioListId == nil || !lists.contains(where: { $0.id == selectedPortfolioListId })) {
        selectedPortfolioListId = lists.first?.id
      }

      async let stocksTask = service.fetchPortfolio(portfolioListId: selectedPortfolioListId)
      async let summaryTask = service.fetchPortfolioSummary(portfolioListId: selectedPortfolioListId)
      let (remoteStocks, summary) = try await (stocksTask, summaryTask)
      await syncWithSwiftData(remoteStocks, listId: selectedPortfolioListId)
      cashBalance = extractCashBalance(from: summary)
      hasLoadedOnce = true
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load portfolio."
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

  private func refreshPortfolioSummary() async {
    do {
      let summary = try await service.fetchPortfolioSummary(portfolioListId: selectedPortfolioListId)
      cashBalance = extractCashBalance(from: summary)
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

  init(context: ModelContext) {
    self.modelContext = context
  }

  func reconcile(with remoteStocks: [StockResponse], in portfolioListId: String?) throws {
    let remoteIds = remoteStocks.map(\.id)
    let listId = portfolioListId ?? ""

    let staleDescriptor: FetchDescriptor<SDPortfolioStock>
    if remoteIds.isEmpty {
      staleDescriptor = FetchDescriptor<SDPortfolioStock>(
        predicate: #Predicate { local in
          (local.portfolioListId ?? "") == listId
        }
      )
    } else {
      staleDescriptor = FetchDescriptor<SDPortfolioStock>(
        predicate: #Predicate { local in
          (local.portfolioListId ?? "") == listId && !remoteIds.contains(local.id)
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
          remoteIds.contains(local.id)
        }
      )
      let touchedRows = try modelContext.fetch(touchedDescriptor)
      existingById = Dictionary(uniqueKeysWithValues: touchedRows.map { ($0.id, $0) })
    }

    for remote in remoteStocks {
      if let local = existingById[remote.id] {
        local.update(from: remote)
        local.portfolioListId = listId
      } else {
        let local = SDPortfolioStock(from: remote)
        local.portfolioListId = listId
        modelContext.insert(local)
      }
    }

    if modelContext.hasChanges {
      try modelContext.save()
    }
  }

  func upsert(_ stock: StockResponse, in portfolioListId: String?) throws {
    let id = stock.id
    let listId = portfolioListId ?? ""
    let descriptor = FetchDescriptor<SDPortfolioStock>(predicate: #Predicate { $0.id == id })
    if let existing = try modelContext.fetch(descriptor).first {
      existing.update(from: stock)
      existing.portfolioListId = listId
    } else {
      let local = SDPortfolioStock(from: stock)
      local.portfolioListId = listId
      modelContext.insert(local)
    }
    if modelContext.hasChanges {
      try modelContext.save()
    }
  }

  func delete(id: String) throws {
    let descriptor = FetchDescriptor<SDPortfolioStock>(predicate: #Predicate { $0.id == id })
    if let existing = try modelContext.fetch(descriptor).first {
      modelContext.delete(existing)
    }
    if modelContext.hasChanges {
      try modelContext.save()
    }
  }
}
