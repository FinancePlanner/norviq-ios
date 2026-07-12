import Foundation
import SwiftData
import StockPlanShared

@Model
final class SDCryptoWatchlistItem {
    #Index<SDCryptoWatchlistItem>([\.symbol], [\.status], [\.ownerUserId])

    @Attribute(.unique) var id: String
    var ownerUserId: String?
    var symbol: String
    var name: String
    var note: String?
    var status: String
    var lastSyncedAt: Date?

    init(
        id: String,
        ownerUserId: String? = nil,
        symbol: String,
        name: String,
        note: String? = nil,
        status: String
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.symbol = symbol
        self.name = name
        self.note = note
        self.status = status
        self.lastSyncedAt = Date()
    }

    init(from response: CryptoWatchlistItemResponse) {
        self.id = response.id
        self.ownerUserId = nil
        self.symbol = response.symbol
        self.name = response.name
        self.note = response.note
        self.status = response.status.rawValue
        self.lastSyncedAt = Date()
    }

    func update(from response: CryptoWatchlistItemResponse) {
        self.symbol = response.symbol
        self.name = response.name
        self.note = response.note
        self.status = response.status.rawValue
        self.lastSyncedAt = Date()
    }
}
