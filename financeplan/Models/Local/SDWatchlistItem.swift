import Foundation
import SwiftData
import StockPlanShared

@Model
final class SDWatchlistItem {
    #Index<SDWatchlistItem>([\.symbol], [\.status], [\.watchlistListId])

    @Attribute(.unique) var id: String
    var symbol: String
    var note: String?
    var status: String
    var nextReviewAt: String?
    var watchlistListId: String?
    var lastSyncedAt: Date?

    init(
        id: String,
        symbol: String,
        note: String? = nil,
        status: String,
        nextReviewAt: String? = nil,
        watchlistListId: String? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.note = note
        self.status = status
        self.nextReviewAt = nextReviewAt
        self.watchlistListId = watchlistListId
        self.lastSyncedAt = Date()
    }

    init(from response: WatchlistItemResponse) {
        self.id = response.id
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
