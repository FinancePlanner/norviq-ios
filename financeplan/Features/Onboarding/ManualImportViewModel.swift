import Combine
import Foundation

@MainActor
final class ManualImportViewModel: ObservableObject {
  @Published var entries: [ManualEntry] = [ManualEntry()]

  func addRow() { entries.append(ManualEntry()) }
  func removeRows(at offsets: IndexSet) {
    for index in offsets.sorted(by: >) {
      entries.remove(at: index)
    }
  }

  func buildPositions() -> [ImportedPosition] {
    entries.compactMap { entry in
      let symbol = entry.symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
      guard !symbol.isEmpty else { return nil }
      let qty = Double(entry.quantity.replacingOccurrences(of: ",", with: "")) ?? 0
      let price = Double(entry.price.replacingOccurrences(of: ",", with: "")) ?? 0
      guard qty > 0 else { return nil }
      return ImportedPosition(symbol: symbol, quantity: qty, price: price)
    }
  }
}

