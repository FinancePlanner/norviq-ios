import Foundation

// MARK: - Grocery / everyday item trackers (/v1/macro/items)

/// One tracked everyday item (eggs, milk, gasoline, ...) for a country.
/// `latestPrice` is populated only where the source publishes average prices
/// (US BLS APU series); index-only sources (Eurostat COICOP) populate
/// `changeYoY` and leave `latestPrice` nil.
public struct MacroItemDTO: Codable, Sendable, Equatable, Identifiable {
    public let id: String // "eggs", "milk", "gasoline", ...
    public let name: String
    public let emoji: String?
    public let country: String
    public let currency: String
    public let unit: String // "USD per dozen", "percent", ...
    public let latestPrice: Double?
    public let changeYoY: Double?
    public let changeMoM: Double?
    public let asOf: String?
    public let source: String
    public let hasSeries: Bool

    public init(
        id: String,
        name: String,
        emoji: String? = nil,
        country: String,
        currency: String,
        unit: String,
        latestPrice: Double? = nil,
        changeYoY: Double? = nil,
        changeMoM: Double? = nil,
        asOf: String? = nil,
        source: String,
        hasSeries: Bool = true
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.country = country
        self.currency = currency
        self.unit = unit
        self.latestPrice = latestPrice
        self.changeYoY = changeYoY
        self.changeMoM = changeMoM
        self.asOf = asOf
        self.source = source
        self.hasSeries = hasSeries
    }
}

public struct MacroItemsResponse: Codable, Sendable, Equatable {
    public let country: String
    public let updatedAt: String
    public let items: [MacroItemDTO]

    public init(country: String, updatedAt: String, items: [MacroItemDTO]) {
        self.country = country
        self.updatedAt = updatedAt
        self.items = items
    }
}

public struct MacroItemSeriesResponse: Codable, Sendable, Equatable {
    public let itemId: String
    public let country: String
    public let currency: String
    public let unit: String
    public let points: [MacroSeriesPoint]

    public init(
        itemId: String,
        country: String,
        currency: String,
        unit: String,
        points: [MacroSeriesPoint]
    ) {
        self.itemId = itemId
        self.country = country
        self.currency = currency
        self.unit = unit
        self.points = points
    }
}
