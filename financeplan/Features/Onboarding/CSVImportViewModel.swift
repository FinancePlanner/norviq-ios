import Combine
import Foundation

@MainActor
final class CSVImportViewModel: ObservableObject {
  @Published var previewRows: [ImportedPosition] = []
  @Published var errorMessage: String?

  func loadCSV(from url: URL) {
    do {
      let data = try Data(contentsOf: url)
      guard let text = String(data: data, encoding: .utf8) else {
        throw CocoaError(.fileReadInapplicableStringEncoding)
      }
      previewRows = parseCSV(text)
      errorMessage = nil
    } catch {
      errorMessage = "Failed to read CSV: \(error.localizedDescription)"
      previewRows = []
    }
  }

  func parseCSV(_ text: String) -> [ImportedPosition] {
    var rows: [ImportedPosition] = []
    let lines = text.split(whereSeparator: \.isNewline)
    guard !lines.isEmpty else { return [] }

    let startIndex = lines.first?.contains(",") == true ? 1 : 0

    for line in lines.dropFirst(startIndex) {
      let parts = line.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
      guard parts.count >= 3 else { continue }
      let symbol = parts[0].uppercased()
      let qty = Double(parts[1]) ?? 0
      let price = Double(parts[2]) ?? 0
      guard !symbol.isEmpty, qty > 0 else { continue }
      rows.append(ImportedPosition(symbol: symbol, quantity: qty, price: price))
    }
    return rows
  }
}
