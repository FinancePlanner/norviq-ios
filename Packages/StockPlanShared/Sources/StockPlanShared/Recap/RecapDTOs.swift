import Foundation

public enum RecapPeriodKind: String, Codable, Sendable, Equatable {
    case month, year
}

public struct RecapMoney: Codable, Sendable, Equatable {
    public let amount: Double
    public let currency: String

    public init(amount: Double, currency: String) {
        self.amount = amount
        self.currency = currency
    }
}

public struct RecapTickerStat: Codable, Sendable, Equatable {
    public let symbol: String
    public let touches: Int

    public init(symbol: String, touches: Int) {
        self.symbol = symbol
        self.touches = touches
    }
}

public struct RecapBadge: Codable, Sendable, Equatable {
    public let type: String
    public let tier: String

    public init(type: String, tier: String) {
        self.type = type
        self.tier = tier
    }
}

public struct RecapGrowth: Codable, Sendable, Equatable {
    public let currency: String
    public let startValue: Double
    public let endValue: Double

    public init(currency: String, startValue: Double, endValue: Double) {
        self.currency = currency
        self.startValue = startValue
        self.endValue = endValue
    }
}

public struct RecapIntroSlide: Codable, Sendable, Equatable {
    public let periodLabel: String
    public let activeDays: Int

    public init(periodLabel: String, activeDays: Int) {
        self.periodLabel = periodLabel
        self.activeDays = activeDays
    }
}

public struct RecapStreakSlide: Codable, Sendable, Equatable {
    public let longestStreakDays: Int
    public let activeDays: Int

    public init(longestStreakDays: Int, activeDays: Int) {
        self.longestStreakDays = longestStreakDays
        self.activeDays = activeDays
    }
}

public struct RecapTopTickersSlide: Codable, Sendable, Equatable {
    public let tickers: [RecapTickerStat]

    public init(tickers: [RecapTickerStat]) {
        self.tickers = tickers
    }
}

public struct RecapTradesSlide: Codable, Sendable, Equatable {
    public let tradeCount: Int
    public let buyCount: Int
    public let sellCount: Int
    public let mostTradedSymbol: String?

    public init(tradeCount: Int, buyCount: Int, sellCount: Int, mostTradedSymbol: String?) {
        self.tradeCount = tradeCount
        self.buyCount = buyCount
        self.sellCount = sellCount
        self.mostTradedSymbol = mostTradedSymbol
    }
}

public struct RecapResearchSlide: Codable, Sendable, Equatable {
    public let notesWritten: Int
    public let watchlistAdded: Int
    public let targetsSet: Int
    public let targetsHit: Int

    public init(notesWritten: Int, watchlistAdded: Int, targetsSet: Int, targetsHit: Int) {
        self.notesWritten = notesWritten
        self.watchlistAdded = watchlistAdded
        self.targetsSet = targetsSet
        self.targetsHit = targetsHit
    }
}

public struct RecapGrowthSlide: Codable, Sendable, Equatable {
    public let growth: [RecapGrowth]

    public init(growth: [RecapGrowth]) {
        self.growth = growth
    }
}

public struct RecapDividendsSlide: Codable, Sendable, Equatable {
    public let received: [RecapMoney]
    public let paymentCount: Int
    public let payerCount: Int

    public init(received: [RecapMoney], paymentCount: Int, payerCount: Int) {
        self.received = received
        self.paymentCount = paymentCount
        self.payerCount = payerCount
    }
}

public struct RecapGoalsSlide: Codable, Sendable, Equatable {
    public let contributed: [RecapMoney]
    public let contributionCount: Int

    public init(contributed: [RecapMoney], contributionCount: Int) {
        self.contributed = contributed
        self.contributionCount = contributionCount
    }
}

public struct RecapBadgesSlide: Codable, Sendable, Equatable {
    public let badges: [RecapBadge]
    public let xpEarned: Int

    public init(badges: [RecapBadge], xpEarned: Int) {
        self.badges = badges
        self.xpEarned = xpEarned
    }
}

public struct RecapPersonalitySlide: Codable, Sendable, Equatable {
    public let archetype: RecapArchetype

    public init(archetype: RecapArchetype) {
        self.archetype = archetype
    }
}

public struct RecapMissedYouSlide: Codable, Sendable, Equatable {
    public let bestStreakDays: Int
    public let totalBadges: Int

    public init(bestStreakDays: Int, totalBadges: Int) {
        self.bestStreakDays = bestStreakDays
        self.totalBadges = totalBadges
    }
}

public struct RecapOutroSlide: Codable, Sendable, Equatable {
    public let isFirstChapter: Bool
    public let nextPeriodLabel: String

    public init(isFirstChapter: Bool, nextPeriodLabel: String) {
        self.isFirstChapter = isFirstChapter
        self.nextPeriodLabel = nextPeriodLabel
    }
}

/// Wire shape: `{"type": "<case>", "payload": {...}}`.
///
/// The payload sits under one fixed key with no underscores, so it survives
/// every key strategy the house coders use (`.convertFromSnakeCase` in
/// `JSONDecoder.stockPlanShared`, underscore normalization in the backend
/// decoder). Multi-word `type` values are snake_case (`top_tickers`,
/// `missed_you`); they are values, not keys, so no strategy rewrites them.
public enum RecapSlide: Codable, Sendable, Equatable {
    case intro(RecapIntroSlide)
    case streak(RecapStreakSlide)
    case topTickers(RecapTopTickersSlide)
    case trades(RecapTradesSlide)
    case research(RecapResearchSlide)
    case growth(RecapGrowthSlide)
    case dividends(RecapDividendsSlide)
    case goals(RecapGoalsSlide)
    case badges(RecapBadgesSlide)
    case personality(RecapPersonalitySlide)
    case missedYou(RecapMissedYouSlide)
    case outro(RecapOutroSlide)

    /// Money slides: hidden from share surfaces.
    public var isPrivate: Bool {
        switch self {
        case .growth, .dividends, .goals:
            true
        case .intro, .streak, .topTickers, .trades, .research, .badges, .personality, .missedYou, .outro:
            false
        }
    }

    private enum Kind: String, Codable {
        case intro
        case streak
        case topTickers = "top_tickers"
        case trades
        case research
        case growth
        case dividends
        case goals
        case badges
        case personality
        case missedYou = "missed_you"
        case outro
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .intro: self = try .intro(container.decode(RecapIntroSlide.self, forKey: .payload))
        case .streak: self = try .streak(container.decode(RecapStreakSlide.self, forKey: .payload))
        case .topTickers: self = try .topTickers(container.decode(RecapTopTickersSlide.self, forKey: .payload))
        case .trades: self = try .trades(container.decode(RecapTradesSlide.self, forKey: .payload))
        case .research: self = try .research(container.decode(RecapResearchSlide.self, forKey: .payload))
        case .growth: self = try .growth(container.decode(RecapGrowthSlide.self, forKey: .payload))
        case .dividends: self = try .dividends(container.decode(RecapDividendsSlide.self, forKey: .payload))
        case .goals: self = try .goals(container.decode(RecapGoalsSlide.self, forKey: .payload))
        case .badges: self = try .badges(container.decode(RecapBadgesSlide.self, forKey: .payload))
        case .personality: self = try .personality(container.decode(RecapPersonalitySlide.self, forKey: .payload))
        case .missedYou: self = try .missedYou(container.decode(RecapMissedYouSlide.self, forKey: .payload))
        case .outro: self = try .outro(container.decode(RecapOutroSlide.self, forKey: .payload))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .intro(value):
            try container.encode(Kind.intro, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .streak(value):
            try container.encode(Kind.streak, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .topTickers(value):
            try container.encode(Kind.topTickers, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .trades(value):
            try container.encode(Kind.trades, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .research(value):
            try container.encode(Kind.research, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .growth(value):
            try container.encode(Kind.growth, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .dividends(value):
            try container.encode(Kind.dividends, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .goals(value):
            try container.encode(Kind.goals, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .badges(value):
            try container.encode(Kind.badges, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .personality(value):
            try container.encode(Kind.personality, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .missedYou(value):
            try container.encode(Kind.missedYou, forKey: .type)
            try container.encode(value, forKey: .payload)
        case let .outro(value):
            try container.encode(Kind.outro, forKey: .type)
            try container.encode(value, forKey: .payload)
        }
    }
}

public struct RecapDeck: Codable, Sendable, Equatable {
    public let kind: RecapPeriodKind
    public let key: String
    public let periodLabel: String
    public let archetype: RecapArchetype?
    public let isFirstChapter: Bool
    public let isMissedYou: Bool
    public let slides: [RecapSlide]
    public let schemaVersion: Int

    public init(
        kind: RecapPeriodKind,
        key: String,
        periodLabel: String,
        archetype: RecapArchetype?,
        isFirstChapter: Bool,
        isMissedYou: Bool,
        slides: [RecapSlide],
        schemaVersion: Int
    ) {
        self.kind = kind
        self.key = key
        self.periodLabel = periodLabel
        self.archetype = archetype
        self.isFirstChapter = isFirstChapter
        self.isMissedYou = isMissedYou
        self.slides = slides
        self.schemaVersion = schemaVersion
    }
}

public struct RecapResponse: Codable, Sendable, Equatable {
    public let id: UUID
    public let deck: RecapDeck
    public let generatedAt: Date
    public let openedAt: Date?
    public let completedAt: Date?

    public init(id: UUID, deck: RecapDeck, generatedAt: Date, openedAt: Date?, completedAt: Date?) {
        self.id = id
        self.deck = deck
        self.generatedAt = generatedAt
        self.openedAt = openedAt
        self.completedAt = completedAt
    }
}

public struct RecapSummary: Codable, Sendable, Equatable {
    public let kind: RecapPeriodKind
    public let key: String
    public let periodLabel: String
    public let id: UUID?
    public let generated: Bool
    public let openedAt: Date?
    public let completedAt: Date?

    public init(
        kind: RecapPeriodKind,
        key: String,
        periodLabel: String,
        id: UUID?,
        generated: Bool,
        openedAt: Date?,
        completedAt: Date?
    ) {
        self.kind = kind
        self.key = key
        self.periodLabel = periodLabel
        self.id = id
        self.generated = generated
        self.openedAt = openedAt
        self.completedAt = completedAt
    }
}

public struct RecapListResponse: Codable, Sendable, Equatable {
    public let recaps: [RecapSummary]

    public init(recaps: [RecapSummary]) {
        self.recaps = recaps
    }
}

public struct RecapShareCard: Codable, Sendable, Equatable {
    public let kind: RecapPeriodKind
    public let periodLabel: String
    public let archetype: RecapArchetype
    public let longestStreakDays: Int
    public let tickersResearched: Int
    public let badgesEarned: Int

    public init(
        kind: RecapPeriodKind,
        periodLabel: String,
        archetype: RecapArchetype,
        longestStreakDays: Int,
        tickersResearched: Int,
        badgesEarned: Int
    ) {
        self.kind = kind
        self.periodLabel = periodLabel
        self.archetype = archetype
        self.longestStreakDays = longestStreakDays
        self.tickersResearched = tickersResearched
        self.badgesEarned = badgesEarned
    }
}
