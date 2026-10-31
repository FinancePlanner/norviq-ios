import Foundation

public enum PilotKind: String, Codable, Sendable, CaseIterable {
    case politician
    case fund
}

public enum PilotFollowTargetKind: String, Codable, Sendable, CaseIterable {
    case portfolio
    case watchlist
}

public enum PilotFollowStatus: String, Codable, Sendable, CaseIterable {
    case active
    case paused
}

public struct PilotSummary: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        slug
    }

    public let slug: String
    public let displayName: String
    public let kind: PilotKind
    /// `senate` or `house` for politicians; nil for funds.
    public let chamber: String?
    /// ISO-8601 time of the latest book version; nil before the first ingestion.
    public let updatedAt: String?
    public let holdingsCount: Int

    public init(
        slug: String,
        displayName: String,
        kind: PilotKind,
        chamber: String?,
        updatedAt: String?,
        holdingsCount: Int
    ) {
        self.slug = slug
        self.displayName = displayName
        self.kind = kind
        self.chamber = chamber
        self.updatedAt = updatedAt
        self.holdingsCount = holdingsCount
    }
}

public struct PilotWeight: Codable, Sendable, Equatable {
    public let symbol: String
    /// 0...1. Weights in a book sum to 1.
    public let weight: Double

    public init(symbol: String, weight: Double) {
        self.symbol = symbol
        self.weight = weight
    }
}

public struct PilotDisclosureItem: Codable, Sendable, Equatable {
    public let symbol: String
    /// `buy`, `sell`, `sell_full` or `hold`.
    public let side: String
    /// `stock`, `call` or `put`.
    public let instrument: String
    public let transactionDate: String?
    public let disclosureDate: String?
    public let amountMin: Double?
    public let amountMax: Double?
    /// 13F period such as `2026Q2`; nil for politicians.
    public let period: String?

    public init(
        symbol: String,
        side: String,
        instrument: String,
        transactionDate: String?,
        disclosureDate: String?,
        amountMin: Double?,
        amountMax: Double?,
        period: String?
    ) {
        self.symbol = symbol
        self.side = side
        self.instrument = instrument
        self.transactionDate = transactionDate
        self.disclosureDate = disclosureDate
        self.amountMin = amountMin
        self.amountMax = amountMax
        self.period = period
    }
}

public struct PilotDetail: Codable, Sendable, Equatable {
    public let pilot: PilotSummary
    public let weights: [PilotWeight]
    /// Put trades in the window. They are not mirrored because a portfolio cannot go short.
    public let skippedPuts: Int
    public let recentDisclosures: [PilotDisclosureItem]
    /// Plain-language reporting-lag and pricing disclaimer for this pilot kind.
    public let lagNote: String

    public init(
        pilot: PilotSummary,
        weights: [PilotWeight],
        skippedPuts: Int,
        recentDisclosures: [PilotDisclosureItem],
        lagNote: String
    ) {
        self.pilot = pilot
        self.weights = weights
        self.skippedPuts = skippedPuts
        self.recentDisclosures = recentDisclosures
        self.lagNote = lagNote
    }
}

public struct PilotFollowCreateRequest: Codable, Sendable, Equatable {
    public let pilotSlug: String
    public let targetKind: PilotFollowTargetKind
    /// An existing empty hypothetical portfolio. Nil creates a new one.
    public let portfolioListId: String?
    /// An existing watchlist. Nil creates a new one.
    public let watchlistListId: String?
    /// Required for portfolio targets; ignored for watchlists.
    public let startingCapital: Double?

    public init(
        pilotSlug: String,
        targetKind: PilotFollowTargetKind,
        portfolioListId: String?,
        watchlistListId: String?,
        startingCapital: Double?
    ) {
        self.pilotSlug = pilotSlug
        self.targetKind = targetKind
        self.portfolioListId = portfolioListId
        self.watchlistListId = watchlistListId
        self.startingCapital = startingCapital
    }
}

public struct PilotFollowUpdateRequest: Codable, Sendable, Equatable {
    public let status: PilotFollowStatus

    public init(status: PilotFollowStatus) {
        self.status = status
    }
}

public struct PilotFollowResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let pilot: PilotSummary
    public let targetKind: PilotFollowTargetKind
    public let portfolioListId: String?
    public let watchlistListId: String?
    public let startingCapital: Double?
    public let currency: String
    public let status: PilotFollowStatus
    /// 0 until the first book version has been applied.
    public let appliedVersion: Int
    public let createdAt: String

    public init(
        id: String,
        pilot: PilotSummary,
        targetKind: PilotFollowTargetKind,
        portfolioListId: String?,
        watchlistListId: String?,
        startingCapital: Double?,
        currency: String,
        status: PilotFollowStatus,
        appliedVersion: Int,
        createdAt: String
    ) {
        self.id = id
        self.pilot = pilot
        self.targetKind = targetKind
        self.portfolioListId = portfolioListId
        self.watchlistListId = watchlistListId
        self.startingCapital = startingCapital
        self.currency = currency
        self.status = status
        self.appliedVersion = appliedVersion
        self.createdAt = createdAt
    }
}

public struct PilotFollowEventResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let bookVersion: Int
    /// `buy`, `sell`, `watch_added`, `watch_exited`, `skipped_unpriced` or `skipped_limit`.
    public let kind: String
    public let symbol: String
    public let quantity: Double?
    public let price: Double?
    public let pricedAt: String
    public let note: String?

    public init(
        id: String,
        bookVersion: Int,
        kind: String,
        symbol: String,
        quantity: Double?,
        price: Double?,
        pricedAt: String,
        note: String?
    ) {
        self.id = id
        self.bookVersion = bookVersion
        self.kind = kind
        self.symbol = symbol
        self.quantity = quantity
        self.price = price
        self.pricedAt = pricedAt
        self.note = note
    }
}

public struct PilotFollowSnapshotResponse: Codable, Sendable, Equatable {
    /// `yyyy-MM-dd`.
    public let date: String
    public let value: Double
    public let cash: Double

    public init(date: String, value: Double, cash: Double) {
        self.date = date
        self.value = value
        self.cash = cash
    }
}
