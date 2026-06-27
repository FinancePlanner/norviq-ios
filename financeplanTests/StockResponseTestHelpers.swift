import StockPlanShared

extension StockResponse {
  init(
    id: String,
    symbol: String,
    shares: Double,
    buyPrice: Double,
    buyDate: String,
    notes: String?,
    category: AssetCategory = .stock,
    portfolioListId: String? = nil
  ) {
    self.init(
      id: id,
      symbol: symbol,
      shares: shares,
      buyPrice: buyPrice,
      buyDate: buyDate,
      notes: notes,
      category: category,
      portfolioListId: portfolioListId,
      createdAt: "2026-01-01T00:00:00Z"
    )
  }
}
