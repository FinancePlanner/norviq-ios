import Combine
import Factory
import Foundation
import StockPlanShared

struct PortfolioAllocationSlice: Identifiable, Equatable, Sendable {
  let id: String
  let symbol: String
  let value: Double
  /// Percent of total portfolio value (0–100).
  let percentage: Double
}

@MainActor
final class PortfolioViewModel: ObservableObject {
  @Published private(set) var stocks: [StockResponse] = []
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var editingStock: StockResponse?
  @Published var isSaving = false
  @Published var isDeletingStock = false

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

  /// Cost-basis weights by position value, largest first.
  var allocationSlices: [PortfolioAllocationSlice] {
    let total = totalValue
    guard total > 0 else { return [] }
    return stocks
      .map { stock in
        let value = stock.shares * stock.buyPrice
        return PortfolioAllocationSlice(
          id: stock.id,
          symbol: stock.symbol,
          value: value,
          percentage: (value / total) * 100
        )
      }
      .sorted { $0.value > $1.value }
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

  @discardableResult
  func delete(id: String) async -> Bool {
    guard !isDeletingStock else { return false }
    isDeletingStock = true
    errorMessage = nil
    defer { isDeletingStock = false }

    let old = stocks
    stocks.removeAll(where: { $0.id == id })

    do {
      try await service.delete(id: id)
      if editingStock?.id == id {
        editingStock = nil
      }
      return true
    } catch {
      stocks = old
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
      let saved = try await service.updateStock(updated)

      if let idx = stocks.firstIndex(where: { $0.id == saved.id }) {
        stocks[idx] = saved
      } else {
        stocks.insert(saved, at: 0)
      }

      editingStock = nil
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
