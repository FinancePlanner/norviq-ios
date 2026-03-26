import Combine
import Factory
import Foundation
import StockPlanShared

@MainActor
final class PortfolioViewModel: ObservableObject {
  @Published private(set) var stocks: [StockResponse] = []
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var editingStock: StockResponse?
  @Published var isSaving = false

  private let service: StockServicing

  init(service: StockServicing) {
    self.service = service
  }

  convenience init() {
    self.init(service: Container.shared.stockService())
  }

  var totalValue: Double {
    stocks.reduce(0) { $0 + ($1.shares * $1.buyPrice) }
  }

  var totalShares: Double {
    stocks.reduce(0) { $0 + $1.shares }
  }

  var averagePositionValue: Double {
    guard !stocks.isEmpty else { return 0 }
    return totalValue / Double(stocks.count)
  }

  func load() async {
    guard !isLoading else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      stocks = try await service.fetchPortfolio()
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load portfolio."
    }
  }

  func delete(id: String) async {
    let old = stocks
    stocks.removeAll(where: { $0.id == id })

    do {
      try await service.delete(id: id)
    } catch {
      stocks = old
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to delete stock."
    }
  }

  func beginEdit(_ stock: StockResponse) {
    editingStock = stock
  }

  func saveEdit(_ updated: StockResponse) async {
    guard !isSaving else { return }
    isSaving = true
    defer { isSaving = false }

    do {
      let saved = try await service.updateStock(updated)

      if let idx = stocks.firstIndex(where: { $0.id == saved.id }) {
        stocks[idx] = saved
      } else {
        stocks.insert(saved, at: 0)
      }

      editingStock = nil
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to update stock."
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
          buyDate: Self.dateOnlyFormatter.string(from: draft.buyDate),
          notes: draft.notes.isEmpty ? nil : draft.notes
        )
      )

      if let idx = stocks.firstIndex(where: { $0.id == saved.id }) {
        stocks[idx] = saved
      } else {
        stocks.insert(saved, at: 0)
      }

      return nil
    } catch {
      let message = (error as? LocalizedError)?.errorDescription ?? "Failed to create stock."
      errorMessage = message
      return message
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
