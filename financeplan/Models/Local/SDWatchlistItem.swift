import Foundation
import SwiftData
import StockPlanShared

@Model
final class SDWatchlistItem {
    #Index<SDWatchlistItem>([\.symbol], [\.status], [\.watchlistListId], [\.ownerUserId])

    @Attribute(.unique) var id: String
    var ownerUserId: String?
    var symbol: String
    var note: String?
    var status: String
    var nextReviewAt: String?
    var watchlistListId: String?
    var lastSyncedAt: Date?

    init(
        id: String,
        ownerUserId: String? = nil,
        symbol: String,
        note: String? = nil,
        status: String,
        nextReviewAt: String? = nil,
        watchlistListId: String? = nil
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.symbol = symbol
        self.note = note
        self.status = status
        self.nextReviewAt = nextReviewAt
        self.watchlistListId = watchlistListId
        self.lastSyncedAt = Date()
    }

    init(from response: WatchlistItemResponse) {
        self.id = response.id
        self.ownerUserId = nil
        self.symbol = response.symbol
        self.note = response.note
        self.status = response.status.rawValue
        self.nextReviewAt = response.nextReviewAt
        self.watchlistListId = nil
        self.lastSyncedAt = Date()
    }

    func update(from response: WatchlistItemResponse) {
        self.symbol = response.symbol
        self.note = response.note
        self.status = response.status.rawValue
        self.nextReviewAt = response.nextReviewAt
        self.watchlistListId = nil
        self.lastSyncedAt = Date()
    }
}
