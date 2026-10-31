import Foundation

// MARK: - Enums

/// Where an article was written. Decodes unknown values as `.unknown` so an
/// older client keeps working when a new surface is added.
public enum ArticleSource: String, Codable, CaseIterable, Sendable {
    case web
    case ios
    case discord
    case unknown

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ArticleSource(rawValue: raw) ?? .unknown
    }
}

/// `hidden` is a moderator action; `deleted` is the author's soft delete.
public enum ArticleStatus: String, Codable, CaseIterable, Sendable {
    case published
    case hidden
    case deleted
    case unknown

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ArticleStatus(rawValue: raw) ?? .unknown
    }
}

// MARK: - Read models

public struct ArticleAuthor: Codable, Sendable, Equatable {
    public let id: UUID
    public let username: String?
    public let avatarURL: String?

    public init(id: UUID, username: String?, avatarURL: String?) {
        self.id = id
        self.username = username
        self.avatarURL = avatarURL
    }
}

/// Feed row. `code` is the short, URL-safe id used in links.
public struct ArticleSummary: Codable, Sendable, Equatable {
    public let id: UUID
    public let code: String
    public let slug: String
    public let title: String
    public let bulletPoints: [String]
    public let tickers: [String]
    public let author: ArticleAuthor
    public let coverImageId: UUID?
    public let upvoteCount: Int
    public let viewCount: Int
    public let wordCount: Int
    public let status: ArticleStatus
    public let source: ArticleSource
    public let publishedAt: Date
    public let editedAt: Date?

    public init(
        id: UUID, code: String, slug: String, title: String, bulletPoints: [String], tickers: [String],
        author: ArticleAuthor, coverImageId: UUID?, upvoteCount: Int, viewCount: Int, wordCount: Int,
        status: ArticleStatus, source: ArticleSource, publishedAt: Date, editedAt: Date?
    ) {
        self.id = id
        self.code = code
        self.slug = slug
        self.title = title
        self.bulletPoints = bulletPoints
        self.tickers = tickers
        self.author = author
        self.coverImageId = coverImageId
        self.upvoteCount = upvoteCount
        self.viewCount = viewCount
        self.wordCount = wordCount
        self.status = status
        self.source = source
        self.publishedAt = publishedAt
        self.editedAt = editedAt
    }
}

public struct ArticleDetail: Codable, Sendable, Equatable {
    public let article: ArticleSummary
    public let bodyMarkdown: String
    public let disclosure: String
    public let viewerUpvoted: Bool
    public let viewerIsAuthor: Bool

    public init(
        article: ArticleSummary,
        bodyMarkdown: String,
        disclosure: String,
        viewerUpvoted: Bool,
        viewerIsAuthor: Bool
    ) {
        self.article = article
        self.bodyMarkdown = bodyMarkdown
        self.disclosure = disclosure
        self.viewerUpvoted = viewerUpvoted
        self.viewerIsAuthor = viewerIsAuthor
    }
}

public struct ArticleListResponse: Codable, Sendable, Equatable {
    public let items: [ArticleSummary]
    public let nextCursor: String?

    public init(items: [ArticleSummary], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

// MARK: - Writes

/// Create and full-replace update share one shape. `source` is ignored on update.
public struct ArticleWriteRequest: Codable, Sendable, Equatable {
    public let title: String
    public let bodyMarkdown: String
    public let bulletPoints: [String]
    public let tickers: [String]
    public let disclosure: String
    public let coverImageId: UUID?
    public let source: ArticleSource?

    public init(
        title: String, bodyMarkdown: String, bulletPoints: [String], tickers: [String],
        disclosure: String, coverImageId: UUID?, source: ArticleSource?
    ) {
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.bulletPoints = bulletPoints
        self.tickers = tickers
        self.disclosure = disclosure
        self.coverImageId = coverImageId
        self.source = source
    }
}

public struct ArticleVoteResponse: Codable, Sendable, Equatable {
    public let upvoteCount: Int
    public let voted: Bool

    public init(upvoteCount: Int, voted: Bool) {
        self.upvoteCount = upvoteCount
        self.voted = voted
    }
}

public struct ArticleReportRequest: Codable, Sendable, Equatable {
    public let reason: BoardReportReason
    public let note: String?

    public init(reason: BoardReportReason, note: String?) {
        self.reason = reason
        self.note = note
    }
}

public struct ArticleImageUploadResponse: Codable, Sendable, Equatable {
    public let id: UUID

    public init(id: UUID) {
        self.id = id
    }
}

public struct ArticleVisibilityRequest: Codable, Sendable, Equatable {
    public let hidden: Bool

    public init(hidden: Bool) {
        self.hidden = hidden
    }
}
