import Foundation
import StockPlanShared
import SwiftData

/// The last ticker the device saw, so the strip paints instantly on launch and
/// keeps showing something on a train. Headlines only, never bodies. Global
/// rather than per-user: the curated feeds are the same for everyone and a
/// user's own feeds are refetched on sign-in.
@Model
final class LocalNewsTickerItem {
    @Attribute(.unique) var id: String
    var title: String
    var url: String?
    var source: String
    var sourceUrl: String?
    var publishedAt: String
    var position: Int
    var fetchedAt: Date

    init(item: NewsTickerItem, position: Int, fetchedAt: Date) {
        self.id = item.id
        self.title = item.title
        self.url = item.url
        self.source = item.source
        self.sourceUrl = item.sourceUrl
        self.publishedAt = item.publishedAt
        self.position = position
        self.fetchedAt = fetchedAt
    }

    var asItem: NewsTickerItem {
        NewsTickerItem(id: id, title: title, url: url, source: source, sourceUrl: sourceUrl, publishedAt: publishedAt)
    }
}

/// Whole-snapshot cache: every refresh replaces the set. Small enough (tens of
/// rows) that a diff would be more code than it saves.
@MainActor
struct NewsTickerLocalStore {
    let container: ModelContainer

    init(container: ModelContainer = sharedModelContainer) {
        self.container = container
    }

    func load() throws -> (items: [NewsTickerItem], fetchedAt: Date?) {
        let context = container.mainContext
        let rows = try context.fetch(FetchDescriptor<LocalNewsTickerItem>(sortBy: [SortDescriptor(\.position)]))
        return (rows.map(\.asItem), rows.first?.fetchedAt)
    }

    func replace(with items: [NewsTickerItem], fetchedAt: Date) throws {
        let context = container.mainContext
        try context.delete(model: LocalNewsTickerItem.self)
        for (index, item) in items.enumerated() {
            context.insert(LocalNewsTickerItem(item: item, position: index, fetchedAt: fetchedAt))
        }
        try context.save()
    }
}
