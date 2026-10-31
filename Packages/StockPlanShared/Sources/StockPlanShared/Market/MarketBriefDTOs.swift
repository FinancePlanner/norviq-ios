import Foundation

/// Which of the two daily briefs. Morning runs 15 minutes after the European
/// open (08:15 Lisbon); evening runs after the US close (22:30 Lisbon).
public enum MarketBriefSlot: String, Codable, Sendable, CaseIterable, Hashable {
    case morning
    case evening
}

/// Sign of a move. Clients draw 🟢 / 🔴 / ⚪️ from it; the formatted numbers
/// stay unsigned.
public enum MarketBriefDirection: String, Codable, Sendable {
    case up
    case down
    case flat

    /// Unknown values decode as `.flat` so a newer server never breaks an
    /// older client's card; the row just renders neutral.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MarketBriefDirection(rawValue: raw) ?? .flat
    }
}

public enum MarketBriefItemKind: String, Codable, Sendable {
    /// Morning 📌 line.
    case highlight
    /// Morning 📍 line: a company reporting today.
    case earnings
    /// Evening numbered story.
    case story
}

/// One index line, e.g. 🇩🇪 DAX → 25.032 → 🔴 0,77%.
public struct MarketBriefQuoteRow: Codable, Sendable, Equatable {
    public let symbol: String
    public let flag: String
    public let name: String
    /// Already formatted for `MarketBriefResponse.language`, e.g. "25.032".
    public let level: String
    /// Unsigned and formatted, e.g. "0,77%". `direction` carries the sign.
    public let changePercent: String
    public let direction: MarketBriefDirection

    public init(
        symbol: String,
        flag: String,
        name: String,
        level: String,
        changePercent: String,
        direction: MarketBriefDirection
    ) {
        self.symbol = symbol
        self.flag = flag
        self.name = name
        self.level = level
        self.changePercent = changePercent
        self.direction = direction
    }
}

/// A headed block of rows, e.g. "Futuros americanos negativos".
public struct MarketBriefQuoteGroup: Codable, Sendable, Equatable {
    /// `eu_open`, `us_futures`, `eu_close` or `us_close`.
    public let id: String
    public let title: String
    /// Worked out on the server from the rows; never written by the model.
    public let tone: MarketBriefDirection
    public let rows: [MarketBriefQuoteRow]

    public init(id: String, title: String, tone: MarketBriefDirection, rows: [MarketBriefQuoteRow]) {
        self.id = id
        self.title = title
        self.tone = tone
        self.rows = rows
    }
}

/// One line of text. Summarised, never copied from a publisher.
public struct MarketBriefItem: Codable, Sendable, Equatable {
    public let kind: MarketBriefItemKind
    public let text: String
    /// Without the "$", e.g. ["NVDA"].
    public let tickers: [String]
    /// The https source the line came from, when it used web search.
    public let sourceUrl: String?

    public init(kind: MarketBriefItemKind, text: String, tickers: [String], sourceUrl: String?) {
        self.kind = kind
        self.text = text
        self.tickers = tickers
        self.sourceUrl = sourceUrl
    }
}

/// Points at another stored brief, fetched with `?slot=&date=`.
public struct MarketBriefRef: Codable, Sendable, Equatable {
    public let slot: MarketBriefSlot
    /// Lisbon calendar date, `yyyy-MM-dd`.
    public let tradingDate: String

    public init(slot: MarketBriefSlot, tradingDate: String) {
        self.slot = slot
        self.tradingDate = tradingDate
    }
}

/// `GET /v1/market/brief`. The same for every user; only the language varies.
public struct MarketBriefResponse: Codable, Sendable, Equatable {
    public let enabled: Bool
    /// Lisbon calendar date, `yyyy-MM-dd`. Nil when no brief exists yet.
    public let tradingDate: String?
    public let slot: MarketBriefSlot?
    /// `en` or `pt-PT`.
    public let language: String
    public let greeting: String?
    /// Empty when no market data was fresh (holiday, provider down).
    public let groups: [MarketBriefQuoteGroup]
    public let items: [MarketBriefItem]
    /// ISO 8601. Nil when no brief exists yet.
    public let generatedAt: String?
    /// True when web search was unavailable and the text came from in-house
    /// sources only.
    public let degraded: Bool
    /// The brief before this one in the same language, e.g. last night's
    /// recap behind this morning's brief. Nil when none is stored.
    public let previous: MarketBriefRef?

    public init(
        enabled: Bool,
        tradingDate: String?,
        slot: MarketBriefSlot?,
        language: String,
        greeting: String?,
        groups: [MarketBriefQuoteGroup],
        items: [MarketBriefItem],
        generatedAt: String?,
        degraded: Bool,
        previous: MarketBriefRef? = nil
    ) {
        self.enabled = enabled
        self.tradingDate = tradingDate
        self.slot = slot
        self.language = language
        self.greeting = greeting
        self.groups = groups
        self.items = items
        self.generatedAt = generatedAt
        self.degraded = degraded
        self.previous = previous
    }

    /// Items of a kind this client does not know are dropped rather than
    /// failing the whole brief.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        tradingDate = try container.decodeIfPresent(String.self, forKey: .tradingDate)
        slot = try container.decodeIfPresent(MarketBriefSlot.self, forKey: .slot)
        language = try container.decode(String.self, forKey: .language)
        greeting = try container.decodeIfPresent(String.self, forKey: .greeting)
        groups = try container.decode([MarketBriefQuoteGroup].self, forKey: .groups)
        items = try container.decode([LossyItem].self, forKey: .items).compactMap(\.item)
        generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt)
        degraded = try container.decode(Bool.self, forKey: .degraded)
        previous = try? container.decodeIfPresent(MarketBriefRef.self, forKey: .previous)
    }

    private struct LossyItem: Decodable {
        let item: MarketBriefItem?

        init(from decoder: Decoder) throws {
            item = try? MarketBriefItem(from: decoder)
        }
    }

    /// Feature off (`enabled: false`) or on with nothing generated yet.
    public static func empty(language: String, enabled: Bool) -> MarketBriefResponse {
        MarketBriefResponse(
            enabled: enabled,
            tradingDate: nil,
            slot: nil,
            language: language,
            greeting: nil,
            groups: [],
            items: [],
            generatedAt: nil,
            degraded: false
        )
    }
}

/// `GET` / `PUT /v1/market/brief/notifications`. One push per brief, in
/// `language` (`en` or `pt-PT`).
public struct MarketBriefNotificationPreferences: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let language: String

    public init(enabled: Bool, language: String) {
        self.enabled = enabled
        self.language = language
    }
}
