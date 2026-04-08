import Foundation
import SwiftData
import StockPlanShared

@Model
final class SDPortfolioStock {
    @Attribute(.unique) var id: String
    var symbol: String
    var shares: Double
    var buyPrice: Double
    var buyDate: String
    var notes: String?
    var category: String?
    var lastSyncedAt: Date?

    init(id: String, symbol: String, shares: Double, buyPrice: Double, buyDate: String, notes: String? = nil, category: String? = "stock") {
        self.id = id
        self.symbol = symbol
        self.shares = shares
        self.buyPrice = buyPrice
        self.buyDate = buyDate
        self.notes = notes
        self.category = category
        self.lastSyncedAt = Date()
    }

    init(from response: StockResponse) {
        self.id = response.id
        self.symbol = response.symbol
        self.shares = response.shares
        self.buyPrice = response.buyPrice
        self.buyDate = response.buyDate
        self.notes = response.notes
        self.category = response.category.rawValue
        self.lastSyncedAt = Date()
    }

    func update(from response: StockResponse) {
        self.symbol = response.symbol
        self.shares = response.shares
        self.buyPrice = response.buyPrice
        self.buyDate = response.buyDate
        self.notes = response.notes
        self.category = response.category.rawValue
        self.lastSyncedAt = Date()
    }
}
