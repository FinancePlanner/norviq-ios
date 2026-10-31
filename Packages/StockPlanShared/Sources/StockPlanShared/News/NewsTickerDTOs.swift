import Foundation

/// One headline on the breaking-news ticker. Headline, source, time and a
/// link out — never a body, so the ticker stays clear of App Store review and
/// publishers' terms.
public struct NewsTickerItem: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let url: String?
    public let source: String
    public let sourceUrl: String?
    public let publishedAt: String

    public init(
        id: String,
        title: String,
        url: String?,
        source: String,
        sourceUrl: String? = nil,
        publishedAt: String
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.source = source
        self.sourceUrl = sourceUrl
        self.publishedAt = publishedAt
    }
}

public struct NewsTickerResponse: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let items: [NewsTickerItem]
    public let generatedAt: String
    /// True when at least one feed is serving cached items after a failed fetch.
    public let stale: Bool

    public init(enabled: Bool, items: [NewsTickerItem], generatedAt: String, stale: Bool) {
        self.enabled = enabled
        self.items = items
        self.generatedAt = generatedAt
        self.stale = stale
    }
}

public struct NewsTickerSettings: Codable, Sendable, Equatable {
    public let enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }
}

public struct UpdateNewsTickerSettingsRequest: Codable, Sendable, Equatable {
    public let enabled: Bool

    public init(enabled: Bool) {
        self.enabled = enabled
    }
}

/// A feed the user added themselves. Private to that user.
public struct NewsTickerFeed: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let url: String
    public let title: String?

    public init(id: String, url: String, title: String?) {
        self.id = id
        self.url = url
        self.title = title
    }
}

public struct NewsTickerFeedsResponse: Codable, Sendable, Equatable {
    public let feeds: [NewsTickerFeed]
    public let maxFeeds: Int

    public init(feeds: [NewsTickerFeed], maxFeeds: Int) {
        self.feeds = feeds
        self.maxFeeds = maxFeeds
    }
}

/// Any site or feed URL; the server discovers the feed behind a site URL.
public struct AddNewsTickerFeedRequest: Codable, Sendable, Equatable {
    public let url: String

    public init(url: String) {
        self.url = url
    }
}
