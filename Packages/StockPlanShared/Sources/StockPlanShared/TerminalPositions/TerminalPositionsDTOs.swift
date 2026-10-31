import Foundation

/// One terminal scenario row. Inputs are stored; the derived fields are
/// recomputed by `TerminalMath` on every read and are nil when
/// `scenarioError` is set.
public struct TerminalPositionResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let ticker: String
    public let sharesOutstanding: Double?
    public let terminalShareCount: Double
    public let terminalMarketCap: Double
    public let valueWanted: Double
    public let sharesOwned: Double
    public let currentSharePrice: Double?
    public let notes: String?
    public let sortOrder: Int
    public let terminalSharePrice: Double?
    public let sharesNeeded: Double?
    public let capitalAtTodayPrice: Double?
    public let progress: Double?
    public let sharesStillNeeded: Double?
    public let gapValueAtTerminal: Double?
    /// `TerminalScenarioError` raw value.
    public let scenarioError: String?
    public let createdAt: String
    public let updatedAt: String

    public init(
        id: String,
        ticker: String,
        sharesOutstanding: Double?,
        terminalShareCount: Double,
        terminalMarketCap: Double,
        valueWanted: Double,
        sharesOwned: Double,
        currentSharePrice: Double?,
        notes: String?,
        sortOrder: Int,
        terminalSharePrice: Double?,
        sharesNeeded: Double?,
        capitalAtTodayPrice: Double?,
        progress: Double?,
        sharesStillNeeded: Double?,
        gapValueAtTerminal: Double?,
        scenarioError: String?,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.ticker = ticker
        self.sharesOutstanding = sharesOutstanding
        self.terminalShareCount = terminalShareCount
        self.terminalMarketCap = terminalMarketCap
        self.valueWanted = valueWanted
        self.sharesOwned = sharesOwned
        self.currentSharePrice = currentSharePrice
        self.notes = notes
        self.sortOrder = sortOrder
        self.terminalSharePrice = terminalSharePrice
        self.sharesNeeded = sharesNeeded
        self.capitalAtTodayPrice = capitalAtTodayPrice
        self.progress = progress
        self.sharesStillNeeded = sharesStillNeeded
        self.gapValueAtTerminal = gapValueAtTerminal
        self.scenarioError = scenarioError
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct TerminalPositionCreateRequest: Codable, Sendable, Equatable {
    public let ticker: String
    public let sharesOutstanding: Double?
    public let terminalShareCount: Double
    public let terminalMarketCap: Double
    public let valueWanted: Double
    public let sharesOwned: Double?
    public let currentSharePrice: Double?
    public let notes: String?

    public init(
        ticker: String,
        sharesOutstanding: Double? = nil,
        terminalShareCount: Double,
        terminalMarketCap: Double,
        valueWanted: Double,
        sharesOwned: Double? = nil,
        currentSharePrice: Double? = nil,
        notes: String? = nil
    ) {
        self.ticker = ticker
        self.sharesOutstanding = sharesOutstanding
        self.terminalShareCount = terminalShareCount
        self.terminalMarketCap = terminalMarketCap
        self.valueWanted = valueWanted
        self.sharesOwned = sharesOwned
        self.currentSharePrice = currentSharePrice
        self.notes = notes
    }
}

/// PATCH body: only non-nil fields change. `clear` sets nullable fields back
/// to nil: "sharesOutstanding", "currentSharePrice", "notes".
public struct TerminalPositionUpdateRequest: Codable, Sendable, Equatable {
    public let ticker: String?
    public let sharesOutstanding: Double?
    public let terminalShareCount: Double?
    public let terminalMarketCap: Double?
    public let valueWanted: Double?
    public let sharesOwned: Double?
    public let currentSharePrice: Double?
    public let notes: String?
    public let clear: [String]?

    public init(
        ticker: String? = nil,
        sharesOutstanding: Double? = nil,
        terminalShareCount: Double? = nil,
        terminalMarketCap: Double? = nil,
        valueWanted: Double? = nil,
        sharesOwned: Double? = nil,
        currentSharePrice: Double? = nil,
        notes: String? = nil,
        clear: [String]? = nil
    ) {
        self.ticker = ticker
        self.sharesOutstanding = sharesOutstanding
        self.terminalShareCount = terminalShareCount
        self.terminalMarketCap = terminalMarketCap
        self.valueWanted = valueWanted
        self.sharesOwned = sharesOwned
        self.currentSharePrice = currentSharePrice
        self.notes = notes
        self.clear = clear
    }
}

/// Every position id, in the new order.
public struct TerminalPositionOrderRequest: Codable, Sendable, Equatable {
    public let ids: [String]

    public init(ids: [String]) {
        self.ids = ids
    }
}

public struct TerminalPositionsListResponse: Codable, Sendable, Equatable {
    public let currency: String
    public let positions: [TerminalPositionResponse]

    public init(currency: String, positions: [TerminalPositionResponse]) {
        self.currency = currency
        self.positions = positions
    }
}

public struct AutobuyResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let ticker: String?
    public let label: String
    /// For `percentOfContribution`, the monthly base the percent applies to.
    public let amount: Double
    public let cadence: AutobuyCadence
    public let percent: Double?
    public let active: Bool
    public let monthlyEquivalent: Double?
    public let createdAt: String
    public let updatedAt: String

    public init(
        id: String,
        ticker: String?,
        label: String,
        amount: Double,
        cadence: AutobuyCadence,
        percent: Double?,
        active: Bool,
        monthlyEquivalent: Double?,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.ticker = ticker
        self.label = label
        self.amount = amount
        self.cadence = cadence
        self.percent = percent
        self.active = active
        self.monthlyEquivalent = monthlyEquivalent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AutobuyCreateRequest: Codable, Sendable, Equatable {
    public let ticker: String?
    public let label: String
    public let amount: Double
    public let cadence: AutobuyCadence
    public let percent: Double?
    public let active: Bool?

    public init(
        ticker: String? = nil,
        label: String,
        amount: Double,
        cadence: AutobuyCadence,
        percent: Double? = nil,
        active: Bool? = nil
    ) {
        self.ticker = ticker
        self.label = label
        self.amount = amount
        self.cadence = cadence
        self.percent = percent
        self.active = active
    }
}

/// PATCH body; `clear` accepts "ticker" and "percent".
public struct AutobuyUpdateRequest: Codable, Sendable, Equatable {
    public let ticker: String?
    public let label: String?
    public let amount: Double?
    public let cadence: AutobuyCadence?
    public let percent: Double?
    public let active: Bool?
    public let clear: [String]?

    public init(
        ticker: String? = nil,
        label: String? = nil,
        amount: Double? = nil,
        cadence: AutobuyCadence? = nil,
        percent: Double? = nil,
        active: Bool? = nil,
        clear: [String]? = nil
    ) {
        self.ticker = ticker
        self.label = label
        self.amount = amount
        self.cadence = cadence
        self.percent = percent
        self.active = active
        self.clear = clear
    }
}

public struct AutobuysListResponse: Codable, Sendable, Equatable {
    public let currency: String
    public let autobuys: [AutobuyResponse]
    public let monthlyTotal: Double

    public init(currency: String, autobuys: [AutobuyResponse], monthlyTotal: Double) {
        self.currency = currency
        self.autobuys = autobuys
        self.monthlyTotal = monthlyTotal
    }
}

/// Totals over valid rows. "Total shares-needed notional at terminal prices"
/// is not a field: it always equals `totalValueWanted` by construction.
public struct TerminalPositionsSummaryResponse: Codable, Sendable, Equatable {
    public let currency: String
    public let positionCount: Int
    public let totalValueWanted: Double
    public let totalGapValueAtTerminal: Double
    public let totalCapitalAtTodayPrice: Double?
    public let pricedPositionCount: Int
    public let monthlyAutobuyTotal: Double
    /// Up to three valid rows, highest `valueWanted` first.
    public let topPositions: [TerminalPositionResponse]

    public init(
        currency: String,
        positionCount: Int,
        totalValueWanted: Double,
        totalGapValueAtTerminal: Double,
        totalCapitalAtTodayPrice: Double?,
        pricedPositionCount: Int,
        monthlyAutobuyTotal: Double,
        topPositions: [TerminalPositionResponse]
    ) {
        self.currency = currency
        self.positionCount = positionCount
        self.totalValueWanted = totalValueWanted
        self.totalGapValueAtTerminal = totalGapValueAtTerminal
        self.totalCapitalAtTodayPrice = totalCapitalAtTodayPrice
        self.pricedPositionCount = pricedPositionCount
        self.monthlyAutobuyTotal = monthlyAutobuyTotal
        self.topPositions = topPositions
    }
}

public struct ShareFactsRequest: Codable, Sendable, Equatable {
    public let ticker: String

    public init(ticker: String) {
        self.ticker = ticker
    }
}

/// AI suggestion with sources. Never saved until the user accepts it.
public struct ShareFactsSuggestion: Codable, Sendable, Equatable {
    public let ticker: String
    public let sharesOutstanding: Double?
    public let currentSharePrice: Double?
    public let currency: String?
    public let asOf: String?
    public let sources: [String]

    public init(
        ticker: String,
        sharesOutstanding: Double?,
        currentSharePrice: Double?,
        currency: String?,
        asOf: String?,
        sources: [String]
    ) {
        self.ticker = ticker
        self.sharesOutstanding = sharesOutstanding
        self.currentSharePrice = currentSharePrice
        self.currency = currency
        self.asOf = asOf
        self.sources = sources
    }
}

public struct TerminalScenarioSuggestionRequest: Codable, Sendable, Equatable {
    public let ticker: String
    /// Defaults to 10 on the server.
    public let horizonYears: Int?

    public init(ticker: String, horizonYears: Int? = nil) {
        self.ticker = ticker
        self.horizonYears = horizonYears
    }
}

/// AI-proposed terminal assumptions with a short rationale and sources.
public struct TerminalScenarioSuggestion: Codable, Sendable, Equatable {
    public let ticker: String
    public let terminalShareCount: Double
    public let terminalMarketCap: Double
    public let horizonYears: Int
    public let rationale: String
    public let sources: [String]

    public init(
        ticker: String,
        terminalShareCount: Double,
        terminalMarketCap: Double,
        horizonYears: Int,
        rationale: String,
        sources: [String]
    ) {
        self.ticker = ticker
        self.terminalShareCount = terminalShareCount
        self.terminalMarketCap = terminalMarketCap
        self.horizonYears = horizonYears
        self.rationale = rationale
        self.sources = sources
    }
}
