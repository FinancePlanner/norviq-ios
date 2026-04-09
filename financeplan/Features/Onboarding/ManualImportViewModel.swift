import Combine
import Foundation
import Factory
import StockPlanShared

@MainActor
final class ManualImportViewModel: ObservableObject {
  @Published var entries: [ManualEntry] = [ManualEntry()]
  private let bulkCreateStocks: @Sendable ([StockRequest]) async throws -> BulkStockResponse

  init(stockService: any StockServicing = Container.shared.stockService()) {
    self.bulkCreateStocks = { requests in
      try await stockService.bulkCreate(stocks: requests)
    }
  }

  init(
    bulkCreateStocks: @escaping @Sendable ([StockRequest]) async throws -> BulkStockResponse
  ) {
    self.bulkCreateStocks = bulkCreateStocks
  }

  func addRow() { entries.append(ManualEntry()) }
  func removeRows(at offsets: IndexSet) {
    for index in offsets.sorted(by: >) {
      entries.remove(at: index)
    }
  }

  func buildPositions() -> [ImportedPosition] {
    entries.compactMap { entry in
      let symbol = entry.symbol.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).uppercased()
      guard !symbol.isEmpty else { return nil }
      let qty = Double(entry.quantity.replacingOccurrences(of: ",", with: "")) ?? 0
      let price = Double(entry.price.replacingOccurrences(of: ",", with: "")) ?? 0
      guard qty > 0 else { return nil }
      return ImportedPosition(symbol: symbol, quantity: qty, price: price)
    }
  }

  func importPositions(
    _ positions: [ImportedPosition],
    buyDate: String = DateFormatter.yyyyMMdd.string(from: Date())
  ) async throws {
    let requests = positions.map { position in
      StockRequest(
        symbol: position.symbol,
        shares: position.quantity,
        buyPrice: position.price,
        buyDate: buyDate,
        notes: ""
      )
    }

    _ = try await bulkCreateStocks(requests)
  }
}
