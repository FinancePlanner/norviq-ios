import Foundation

/// An owner's public link. `scope` is a portfolio UUID string or "all".
public struct PortfolioShareLinkResponse: Codable, Sendable, Equatable {
    public let slug: String
    public let url: String
    public let scope: String
    public let createdAt: String

    public init(slug: String, url: String, scope: String, createdAt: String) {
        self.slug = slug
        self.url = url
        self.scope = scope
        self.createdAt = createdAt
    }
}

/// GET answer: `link` is nil when nothing is being shared, so clients never
/// have to interpret a 404.
public struct PortfolioShareLinkStatusResponse: Codable, Sendable, Equatable {
    public let link: PortfolioShareLinkResponse?

    public init(link: PortfolioShareLinkResponse?) {
        self.link = link
    }
}

public struct PortfolioShareHolding: Codable, Sendable, Equatable {
    public let symbol: String
    public let weightPercent: Double
    public let unrealizedPnlPercent: Double?
    public let dayChangePercent: Double?

    public init(symbol: String, weightPercent: Double, unrealizedPnlPercent: Double?, dayChangePercent: Double?) {
        self.symbol = symbol
        self.weightPercent = weightPercent
        self.unrealizedPnlPercent = unrealizedPnlPercent
        self.dayChangePercent = dayChangePercent
    }
}

public struct PortfolioShareTotals: Codable, Sendable, Equatable {
    public let unrealizedPnlPercent: Double?
    public let dayChangePercent: Double?
    public let ytdPercent: Double?

    public init(unrealizedPnlPercent: Double?, dayChangePercent: Double?, ytdPercent: Double?) {
        self.unrealizedPnlPercent = unrealizedPnlPercent
        self.dayChangePercent = dayChangePercent
        self.ytdPercent = ytdPercent
    }
}

/// What a stranger sees at /p/{slug}. Deliberately has no field that can hold
/// a money amount, a share count or anything naming the owner — adding one
/// here is a privacy change, not a feature.
public struct PublicPortfolioShareResponse: Codable, Sendable, Equatable {
    public let asOf: String
    public let totals: PortfolioShareTotals
    public let holdings: [PortfolioShareHolding]
    public let otherWeightPercent: Double?

    public init(
        asOf: String,
        totals: PortfolioShareTotals,
        holdings: [PortfolioShareHolding],
        otherWeightPercent: Double?
    ) {
        self.asOf = asOf
        self.totals = totals
        self.holdings = holdings
        self.otherWeightPercent = otherWeightPercent
    }
}
