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

  private let service: StockServicing
  private var modelContext: ModelContext?
  private var hasLoadedOnce = false

  init(service: StockServicing, modelContext: ModelContext? = nil) {
    self.service = service
    self.modelContext = modelContext
  }

  convenience init() {
    self.init(service: Container.shared.stockService())
  }

  func setModelContext(_ context: ModelContext) {
    self.modelContext = context
  }

  func load(force: Bool = false) async {
    if !force, hasLoadedOnce { return }
    guard !isLoading else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let remoteItems = try await service.fetchWatchlist()
      await syncWithSwiftData(remoteItems)
      hasLoadedOnce = true
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func syncWithSwiftData(_ remoteItems: [WatchlistItemResponse]) async {
    guard let modelContext = modelContext else { return }
    let remoteIds = Set(remoteItems.map { $0.id })

    do {
      let descriptor = FetchDescriptor<SDWatchlistItem>()
      let localItems = try modelContext.fetch(descriptor)
      let localById = Dictionary(uniqueKeysWithValues: localItems.map { ($0.id, $0) })

      for local in localItems {
        if !remoteIds.contains(local.id) {
          modelContext.delete(local)
        }
      }

      for remote in remoteItems {
        if let existing = localById[remote.id] {
          existing.update(from: remote)
        } else {
          modelContext.insert(SDWatchlistItem(from: remote))
        }
      }

      try modelContext.save()
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
        )
      )
      
      if let modelContext = modelContext {
        modelContext.insert(SDWatchlistItem(from: created))
        try modelContext.save()
      }

      addWatchlistDraft = AddWatchlistDraft()
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  func savePosition(from item: WatchlistItemResponse, draft: AddPositionDraft) async -> String? {
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

      let saved = try await service.create(stock: request)
      
      // Also update SwiftData for portfolio if possible, but the Portfolio screen will sync anyway.
      // However, we can be proactive.
      // For now, let's just make sure the watchlist item is updated if needed or wait for its sync.
      
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  func removeFromWatchlist(_ item: WatchlistItemResponse) async {
    do {
      try await service.deleteWatchlistItem(id: item.id)
      
      if let modelContext = modelContext {
        let id = item.id
        let descriptor = FetchDescriptor<SDWatchlistItem>(predicate: #Predicate { $0.id == id })
        if let local = try modelContext.fetch(descriptor).first {
          modelContext.delete(local)
          try modelContext.save()
        }
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
