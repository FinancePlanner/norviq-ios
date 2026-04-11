import Combine
import Factory
import Foundation
import OSLog
import StockPlanShared
import SwiftData

private let watchlistViewModelLogger = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "financeplan",
  category: "WatchlistViewModel"
)

@MainActor
final class WatchlistViewModel: ObservableObject {
  @Published var isLoading = false
  @Published var isSaving = false
  @Published var errorMessage: String?

  @Published var isAddWatchlistPresented = false
  @Published var addWatchlistDraft = AddWatchlistDraft()
  @Published private(set) var watchlistLists: [WatchlistListDTOResponse] = []
  @Published var selectedWatchlistListId: String?

  private let service: StockServicing
  private var localStore: (any WatchlistLocalPersisting)?
  private var hasLoadedOnce = false

  init(
    service: StockServicing,
    localStore: (any WatchlistLocalPersisting)? = nil
  ) {
    self.service = service
    self.localStore = localStore
  }

  convenience init() {
    self.init(service: Container.shared.stockService())
  }

  func setModelContext(_ context: ModelContext) {
    self.localStore = SwiftDataWatchlistLocalStore(context: context)
  }

  func load(force: Bool = false) async {
    if !force, hasLoadedOnce { return }
    guard !isLoading else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let lists = try await service.fetchWatchlistLists()
      watchlistLists = lists
      if selectedWatchlistListId == nil || !lists.contains(where: { $0.id == selectedWatchlistListId }) {
        selectedWatchlistListId = lists.first?.id
      }

      let remoteItems = try await service.fetchWatchlist(watchlistListId: selectedWatchlistListId)
      await syncWithSwiftData(remoteItems, listId: selectedWatchlistListId)
      hasLoadedOnce = true
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func syncWithSwiftData(_ remoteItems: [WatchlistItemResponse], listId: String?) async {
    guard let localStore else { return }
    do {
      try localStore.reconcile(with: remoteItems, in: listId)
    } catch {
      watchlistViewModelLogger.error("SwiftData watchlist sync failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  func saveWatchlist(_ draft: AddWatchlistDraft) async -> String? {
    guard !isSaving else { return "Already saving." }
    isSaving = true
    defer { isSaving = false }

    do {
      let created = try await service.createWatchlistItem(
        WatchlistItemRequest(
          symbol: draft.symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
          note: draft.note.isEmpty ? nil : draft.note,
          status: draft.status,
          nextReviewAt: nil
        ),
        watchlistListId: selectedWatchlistListId
      )

      try localStore?.upsert(created, in: selectedWatchlistListId)

      addWatchlistDraft = AddWatchlistDraft()
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  func savePosition(
    from item: WatchlistItemResponse,
    draft: AddPositionDraft,
    portfolioListId: String?
  ) async -> String? {
    guard !isSaving else { return "Already saving." }
    guard let shares = Double(draft.shares), let buyPrice = Double(draft.buyPrice) else {
      return "Enter valid shares and buy price."
    }

    isSaving = true
    defer { isSaving = false }

    do {
      let request = StockRequest(
        symbol: draft.symbol.uppercased(),
        shares: shares,
        buyPrice: buyPrice,
        buyDate: DateFormatter.yyyyMMdd.string(from: draft.buyDate),
        notes: draft.notes.isEmpty ? nil : draft.notes
      )

      _ = try await service.create(stock: request, portfolioListId: portfolioListId)

      return nil
    } catch {
      return error.localizedDescription
    }
  }

  func removeFromWatchlist(_ item: WatchlistItemResponse) async {
    do {
      try await service.deleteWatchlistItem(id: item.id)

      try localStore?.delete(id: item.id)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func selectWatchlistList(_ listId: String) async {
    guard selectedWatchlistListId != listId else { return }
    selectedWatchlistListId = listId
    hasLoadedOnce = false
    await load(force: true)
  }

  func createWatchlistList(name: String) async -> String? {
    let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return "List name is required." }
    do {
      let created = try await service.createWatchlistList(name: normalized)
      selectedWatchlistListId = created.id
      hasLoadedOnce = false
      await load(force: true)
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  func renameWatchlistList(id: String, name: String) async -> String? {
    let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return "List name is required." }
    do {
      _ = try await service.updateWatchlistList(id: id, name: normalized)
      hasLoadedOnce = false
      await load(force: true)
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  func deleteWatchlistList(id: String) async -> String? {
    do {
      try await service.deleteWatchlistList(id: id)
      if selectedWatchlistListId == id {
        selectedWatchlistListId = nil
      }
      hasLoadedOnce = false
      await load(force: true)
      return nil
    } catch {
      return error.localizedDescription
    }
  }
}

@MainActor
protocol WatchlistLocalPersisting {
  func reconcile(with remoteItems: [WatchlistItemResponse], in watchlistListId: String?) throws
  func upsert(_ item: WatchlistItemResponse, in watchlistListId: String?) throws
  func delete(id: String) throws
}

@MainActor
struct SwiftDataWatchlistLocalStore: WatchlistLocalPersisting {
  private let modelContext: ModelContext

  init(context: ModelContext) {
    self.modelContext = context
  }

  func reconcile(with remoteItems: [WatchlistItemResponse], in watchlistListId: String?) throws {
    let remoteIds = remoteItems.map(\.id)
    let listId = watchlistListId ?? ""

    let staleDescriptor: FetchDescriptor<SDWatchlistItem>
    if remoteIds.isEmpty {
      staleDescriptor = FetchDescriptor<SDWatchlistItem>(
        predicate: #Predicate { local in
          (local.watchlistListId ?? "") == listId
        }
      )
    } else {
      staleDescriptor = FetchDescriptor<SDWatchlistItem>(
        predicate: #Predicate { local in
          (local.watchlistListId ?? "") == listId && !remoteIds.contains(local.id)
        }
      )
    }

    let staleRows = try modelContext.fetch(staleDescriptor)
    staleRows.forEach(modelContext.delete)

    let existingById: [String: SDWatchlistItem]
    if remoteIds.isEmpty {
      existingById = [:]
    } else {
      let touchedDescriptor = FetchDescriptor<SDWatchlistItem>(
        predicate: #Predicate { local in
          remoteIds.contains(local.id)
        }
      )
      let touchedRows = try modelContext.fetch(touchedDescriptor)
      existingById = Dictionary(uniqueKeysWithValues: touchedRows.map { ($0.id, $0) })
    }

    for remote in remoteItems {
      if let local = existingById[remote.id] {
        local.update(from: remote)
        local.watchlistListId = listId
      } else {
        let local = SDWatchlistItem(from: remote)
        local.watchlistListId = listId
        modelContext.insert(local)
      }
    }

    if modelContext.hasChanges {
      try modelContext.save()
    }
  }

  func upsert(_ item: WatchlistItemResponse, in watchlistListId: String?) throws {
    let id = item.id
    let listId = watchlistListId ?? ""
    let descriptor = FetchDescriptor<SDWatchlistItem>(predicate: #Predicate { $0.id == id })
    if let existing = try modelContext.fetch(descriptor).first {
      existing.update(from: item)
      existing.watchlistListId = listId
    } else {
      let local = SDWatchlistItem(from: item)
      local.watchlistListId = listId
      modelContext.insert(local)
    }
    if modelContext.hasChanges {
      try modelContext.save()
    }
  }

  func delete(id: String) throws {
    let descriptor = FetchDescriptor<SDWatchlistItem>(predicate: #Predicate { $0.id == id })
    if let existing = try modelContext.fetch(descriptor).first {
      modelContext.delete(existing)
    }
    if modelContext.hasChanges {
      try modelContext.save()
    }
  }
}
