import Combine
import Factory
import Foundation
import StockPlanShared

@MainActor
final class WatchlistViewModel: ObservableObject {
  @Published var items: [WatchlistItemResponse] = []
  @Published var isLoading = false
  @Published var isSaving = false
  @Published var errorMessage: String?

  @Published var isAddWatchlistPresented = false
  @Published var addWatchlistDraft = AddWatchlistDraft()

  private let service: StockServicing

  init(service: StockServicing) {
    self.service = service
  }

  convenience init() {
    self.init(service: Container.shared.stockService())
  }

  func load() async {
    guard !isLoading else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      items = try await service.fetchWatchlist()
    } catch {
      errorMessage = error.localizedDescription
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
      items.insert(created, at: 0)
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
        buyDate: Self.dateOnlyFormatter.string(from: draft.buyDate),
        notes: draft.notes.isEmpty ? nil : draft.notes
      )

      _ = try await service.create(stock: request)
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  func removeFromWatchlist(_ item: WatchlistItemResponse) async {
    let old = items
    items.removeAll { $0.id == item.id }

    do {
      try await service.deleteWatchlistItem(id: item.id)
    } catch {
      items = old
      errorMessage = error.localizedDescription
    }
  }

  private static let dateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .init(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()
}
