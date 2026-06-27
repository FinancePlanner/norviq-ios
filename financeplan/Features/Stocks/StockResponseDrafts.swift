import Foundation
import StockPlanShared

extension StockResponse {
  static func editableDraft(from stock: SDPortfolioStock) -> StockResponse {
    let category = AssetCategory(rawValue: stock.category ?? AssetCategory.stock.rawValue) ?? .stock

    return StockResponse(
      id: stock.id,
      symbol: stock.symbol,
      shares: stock.shares,
      buyPrice: stock.buyPrice,
      buyDate: stock.buyDate,
      notes: stock.notes,
      category: category,
      portfolioListId: stock.portfolioListId,
      createdAt: ISO8601DateFormatter().string(from: stock.lastSyncedAt ?? Date())
    )
  }

  func replacing(notes: String?) -> StockResponse {
    StockResponse(
      id: id,
      symbol: symbol,
      shares: shares,
      buyPrice: buyPrice,
      buyDate: buyDate,
      notes: notes,
      category: category,
      portfolioListId: portfolioListId,
      createdAt: createdAt
    )
  }
}
