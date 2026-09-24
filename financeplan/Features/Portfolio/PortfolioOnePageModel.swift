import Foundation
import StockPlanShared

nonisolated struct PortfolioOnePageRow: Identifiable, Equatable {
  var id: String { symbol }
  let symbol: String
  let weightPercent: Double
  /// Owner-only. The share card must never read this.
  let marketValue: Double?
  let unrealizedPnlPercent: Double?
  let dayChangePercent: Double?
}

/// Holdings reduced to what fits on one screen: the heaviest `maxRows`, with
/// everything else folded into a single "Other" weight.
nonisolated struct PortfolioOnePageModel: Equatable {
  static let defaultMaxRows = 12

  let rows: [PortfolioOnePageRow]
  let otherWeightPercent: Double?

  init(pnl: [PnlBySymbol], maxRows: Int = PortfolioOnePageModel.defaultMaxRows) {
    let totalValue = pnl.reduce(0) { $0 + ($1.marketValue ?? 0) }
    let all = pnl.map { item in
      PortfolioOnePageRow(
        symbol: item.symbol,
        weightPercent: item.weightPercent
          ?? (totalValue > 0 ? (item.marketValue ?? 0) / totalValue * 100 : 0),
        marketValue: item.marketValue,
        unrealizedPnlPercent: item.unrealizedPnlPercent,
        dayChangePercent: item.dayChangePercent
      )
    }
    .sorted { $0.weightPercent > $1.weightPercent }

    rows = Array(all.prefix(maxRows))
    let rest = all.dropFirst(maxRows).reduce(0) { $0 + $1.weightPercent }
    otherWeightPercent = rest > 0 ? rest : nil
  }
}
