import Foundation

public struct AllocationItem: Codable, Sendable, Equatable {
    public let symbol: String
    public let value: Double
    public let currency: String

    public init(symbol: String, value: Double, currency: String) {
        self.symbol = symbol
        self.value = value
        self.currency = currency
    }
}

public struct PortfolioSummaryResponse: Codable, Sendable, Equatable {
    public let baseCurrency: String
    public let totalValue: Double
    public let totalCost: Double
    public let unrealizedPnl: Double
    public let realizedPnl: Double
    public let cashBalance: Double
    public let allocation: [AllocationItem]
    public let dayChange: Double?
    public let dayChangePercent: Double?
    public let unrealizedPnlPercent: Double?
    public let asOf: String?

    public init(
        baseCurrency: String,
        totalValue: Double,
        totalCost: Double,
        unrealizedPnl: Double,
        realizedPnl: Double,
        cashBalance: Double = 0,
        allocation: [AllocationItem],
        dayChange: Double? = nil,
        dayChangePercent: Double? = nil,
        unrealizedPnlPercent: Double? = nil,
        asOf: String? = nil
    ) {
        self.baseCurrency = baseCurrency
        self.totalValue = totalValue
        self.totalCost = totalCost
        self.unrealizedPnl = unrealizedPnl
        self.realizedPnl = realizedPnl
        self.cashBalance = cashBalance
        self.allocation = allocation
        self.dayChange = dayChange
        self.dayChangePercent = dayChangePercent
        self.unrealizedPnlPercent = unrealizedPnlPercent
        self.asOf = asOf
    }

    enum CodingKeys: String, CodingKey {
        case baseCurrency
        case totalValue
        case totalCost
        case unrealizedPnl
        case realizedPnl
        case cashBalance
        case allocation
        case dayChange
        case dayChangePercent
        case unrealizedPnlPercent
        case asOf
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseCurrency = try container.decode(String.self, forKey: .baseCurrency)
        totalValue = try container.decode(Double.self, forKey: .totalValue)
        totalCost = try container.decode(Double.self, forKey: .totalCost)
        unrealizedPnl = try container.decode(Double.self, forKey: .unrealizedPnl)
        realizedPnl = try container.decode(Double.self, forKey: .realizedPnl)
        cashBalance = try container.decodeIfPresent(Double.self, forKey: .cashBalance) ?? 0
        allocation = try container.decode([AllocationItem].self, forKey: .allocation)
        dayChange = try container.decodeIfPresent(Double.self, forKey: .dayChange)
        dayChangePercent = try container.decodeIfPresent(Double.self, forKey: .dayChangePercent)
        unrealizedPnlPercent = try container.decodeIfPresent(Double.self, forKey: .unrealizedPnlPercent)
        asOf = try container.decodeIfPresent(String.self, forKey: .asOf)
    }
}

public struct PerformancePoint: Codable, Sendable, Equatable {
    /// How a point's value was arrived at. `live` was observed on the day it is
    /// dated; `backfill` was reconstructed afterwards from historical prices and
    /// is approximate — see the backfill notes on the server.
    public enum Source {
        public static let live = "live"
        public static let backfill = "backfill"
    }

    public let date: String
    public let value: Double
    public let costBasis: Double?
    /// `Source.live` / `Source.backfill`. Absent from backends predating snapshots.
    public let source: String?

    public init(
        date: String,
        value: Double,
        costBasis: Double? = nil,
        source: String? = nil
    ) {
        self.date = date
        self.value = value
        self.costBasis = costBasis
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case date
        case value
        case costBasis
        case source
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        value = try container.decode(Double.self, forKey: .value)
        costBasis = try container.decodeIfPresent(Double.self, forKey: .costBasis)
        source = try container.decodeIfPresent(String.self, forKey: .source)
    }
}

/// One period-over-period change, carrying the window it was measured over so a
/// client can label it truthfully instead of guessing what "period" meant.
public struct PortfolioChange: Codable, Sendable, Equatable {
    /// What the change was measured against. Deliberately a `String` rather than
    /// a Swift enum: clients are pinned to exact package versions, so a new basis
    /// added by the server must not fail decoding of the whole response.
    public enum Basis {
        public static let previousTradingDay = "previousTradingDay"
        public static let week = "week"
        public static let month = "month"
        public static let ytd = "ytd"
        public static let inception = "inception"
    }

    /// Fractional, not percentage points: -0.004 is -0.4%.
    public let percent: Double
    public let absolute: Double
    public let fromDate: String
    public let toDate: String
    public let basis: String

    public init(
        percent: Double,
        absolute: Double,
        fromDate: String,
        toDate: String,
        basis: String
    ) {
        self.percent = percent
        self.absolute = absolute
        self.fromDate = fromDate
        self.toDate = toDate
        self.basis = basis
    }
}

/// Changes over the standard windows.
///
/// A member is `nil` when there is not enough history to compute it. `nil` is not
/// zero: render an empty state, never "0.0%". A zero here would claim the
/// portfolio was flat over a window nobody actually measured.
public struct PortfolioChanges: Codable, Sendable, Equatable {
    public let day: PortfolioChange?
    public let week: PortfolioChange?
    public let month: PortfolioChange?
    public let ytd: PortfolioChange?
    public let sinceInception: PortfolioChange?

    public init(
        day: PortfolioChange? = nil,
        week: PortfolioChange? = nil,
        month: PortfolioChange? = nil,
        ytd: PortfolioChange? = nil,
        sinceInception: PortfolioChange? = nil
    ) {
        self.day = day
        self.week = week
        self.month = month
        self.ytd = ytd
        self.sinceInception = sinceInception
    }

    enum CodingKeys: String, CodingKey {
        case day
        case week
        case month
        case ytd
        case sinceInception
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decodeIfPresent(PortfolioChange.self, forKey: .day)
        week = try container.decodeIfPresent(PortfolioChange.self, forKey: .week)
        month = try container.decodeIfPresent(PortfolioChange.self, forKey: .month)
        ytd = try container.decodeIfPresent(PortfolioChange.self, forKey: .ytd)
        sinceInception = try container.decodeIfPresent(
            PortfolioChange.self, forKey: .sinceInception
        )
    }
}

public struct PortfolioPerformanceResponse: Codable, Sendable, Equatable {
    public let baseCurrency: String
    public let points: [PerformancePoint]
    public let range: String?
    /// Date of the most recent point, as the server sees it.
    public let asOf: String?
    /// Absent when the backend predates snapshots; individual members absent when
    /// history is too short. See `PortfolioChanges`.
    public let changes: PortfolioChanges?

    public init(
        baseCurrency: String,
        points: [PerformancePoint],
        range: String? = nil,
        asOf: String? = nil,
        changes: PortfolioChanges? = nil
    ) {
        self.baseCurrency = baseCurrency
        self.points = points
        self.range = range
        self.asOf = asOf
        self.changes = changes
    }

    enum CodingKeys: String, CodingKey {
        case baseCurrency
        case points
        case range
        case asOf
        case changes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseCurrency = try container.decode(String.self, forKey: .baseCurrency)
        points = try container.decode([PerformancePoint].self, forKey: .points)
        range = try container.decodeIfPresent(String.self, forKey: .range)
        asOf = try container.decodeIfPresent(String.self, forKey: .asOf)
        changes = try container.decodeIfPresent(PortfolioChanges.self, forKey: .changes)
    }
}

public struct PortfolioSectorHoldingContribution: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        symbol
    }

    public let symbol: String
    public let value: Double
    public let weightPercent: Double

    public init(symbol: String, value: Double, weightPercent: Double) {
        self.symbol = symbol
        self.value = value
        self.weightPercent = weightPercent
    }
}

public struct PortfolioSectorExposureItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        sector
    }

    public let sector: String
    public let value: Double
    public let weightPercent: Double
    public let benchmarkWeightPercent: Double?
    public let overweightPercent: Double?
    public let holdings: [PortfolioSectorHoldingContribution]

    public init(
        sector: String,
        value: Double,
        weightPercent: Double,
        benchmarkWeightPercent: Double?,
        overweightPercent: Double?,
        holdings: [PortfolioSectorHoldingContribution]
    ) {
        self.sector = sector
        self.value = value
        self.weightPercent = weightPercent
        self.benchmarkWeightPercent = benchmarkWeightPercent
        self.overweightPercent = overweightPercent
        self.holdings = holdings
    }
}

public struct PortfolioSectorExposureResponse: Codable, Sendable, Equatable {
    public let baseCurrency: String
    public let totalValue: Double
    public let investedValue: Double
    public let cashBalance: Double
    public let benchmarkName: String
    public let benchmarkAsOf: String
    public let sectors: [PortfolioSectorExposureItem]

    public init(
        baseCurrency: String,
        totalValue: Double,
        investedValue: Double,
        cashBalance: Double,
        benchmarkName: String,
        benchmarkAsOf: String,
        sectors: [PortfolioSectorExposureItem]
    ) {
        self.baseCurrency = baseCurrency
        self.totalValue = totalValue
        self.investedValue = investedValue
        self.cashBalance = cashBalance
        self.benchmarkName = benchmarkName
        self.benchmarkAsOf = benchmarkAsOf
        self.sectors = sectors
    }
}

public struct SectorGainItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        sector
    }

    public let sector: String
    public let marketValue: Double
    public let costBasis: Double
    public let unrealizedPnl: Double
    public let unrealizedPnlPercent: Double
    public let weightPercent: Double

    public init(
        sector: String,
        marketValue: Double,
        costBasis: Double,
        unrealizedPnl: Double,
        unrealizedPnlPercent: Double,
        weightPercent: Double
    ) {
        self.sector = sector
        self.marketValue = marketValue
        self.costBasis = costBasis
        self.unrealizedPnl = unrealizedPnl
        self.unrealizedPnlPercent = unrealizedPnlPercent
        self.weightPercent = weightPercent
    }
}

public struct SectorGainsResponse: Codable, Sendable, Equatable {
    public let baseCurrency: String
    public let totalMarketValue: Double
    public let totalCostBasis: Double
    public let totalUnrealizedPnl: Double
    public let sectors: [SectorGainItem]

    public init(
        baseCurrency: String,
        totalMarketValue: Double,
        totalCostBasis: Double,
        totalUnrealizedPnl: Double,
        sectors: [SectorGainItem]
    ) {
        self.baseCurrency = baseCurrency
        self.totalMarketValue = totalMarketValue
        self.totalCostBasis = totalCostBasis
        self.totalUnrealizedPnl = totalUnrealizedPnl
        self.sectors = sectors
    }
}

public struct TransactionResponse: Codable, Sendable, Equatable {
    public let id: String
    public let accountId: String
    public let instrumentId: String
    public let type: String
    public let quantity: Double?
    public let price: Double?
    public let currency: String
    public let tradeDate: String
    public let settleDate: String?
    public let fees: Double?

    public init(
        id: String,
        accountId: String,
        instrumentId: String,
        type: String,
        quantity: Double?,
        price: Double?,
        currency: String,
        tradeDate: String,
        settleDate: String?,
        fees: Double?
    ) {
        self.id = id
        self.accountId = accountId
        self.instrumentId = instrumentId
        self.type = type
        self.quantity = quantity
        self.price = price
        self.currency = currency
        self.tradeDate = tradeDate
        self.settleDate = settleDate
        self.fees = fees
    }
}

public struct LotResponse: Codable, Sendable, Equatable {
    public let id: String
    public let accountId: String
    public let instrumentId: String
    public let openDate: String
    public let closeDate: String?
    public let openQuantity: Double
    public let remainingQuantity: Double
    public let openPrice: Double
    public let currency: String
    public let realizedPnl: Double?
    public let status: String

    public init(
        id: String,
        accountId: String,
        instrumentId: String,
        openDate: String,
        closeDate: String?,
        openQuantity: Double,
        remainingQuantity: Double,
        openPrice: Double,
        currency: String,
        realizedPnl: Double?,
        status: String
    ) {
        self.id = id
        self.accountId = accountId
        self.instrumentId = instrumentId
        self.openDate = openDate
        self.closeDate = closeDate
        self.openQuantity = openQuantity
        self.remainingQuantity = remainingQuantity
        self.openPrice = openPrice
        self.currency = currency
        self.realizedPnl = realizedPnl
        self.status = status
    }
}

public struct PnlBySymbol: Codable, Sendable, Equatable {
    public let symbol: String
    public let currency: String
    public let realizedPnl: Double
    public let unrealizedPnl: Double
    public let shares: Double?
    public let buyPrice: Double?
    public let costBasis: Double?
    public let currentPrice: Double?
    public let marketValue: Double?
    public let unrealizedPnlPercent: Double?
    public let dayChange: Double?
    public let dayChangePercent: Double?
    public let weightPercent: Double?

    public init(
        symbol: String,
        currency: String,
        realizedPnl: Double,
        unrealizedPnl: Double,
        shares: Double? = nil,
        buyPrice: Double? = nil,
        costBasis: Double? = nil,
        currentPrice: Double? = nil,
        marketValue: Double? = nil,
        unrealizedPnlPercent: Double? = nil,
        dayChange: Double? = nil,
        dayChangePercent: Double? = nil,
        weightPercent: Double? = nil
    ) {
        self.symbol = symbol
        self.currency = currency
        self.realizedPnl = realizedPnl
        self.unrealizedPnl = unrealizedPnl
        self.shares = shares
        self.buyPrice = buyPrice
        self.costBasis = costBasis
        self.currentPrice = currentPrice
        self.marketValue = marketValue
        self.unrealizedPnlPercent = unrealizedPnlPercent
        self.dayChange = dayChange
        self.dayChangePercent = dayChangePercent
        self.weightPercent = weightPercent
    }

    enum CodingKeys: String, CodingKey {
        case symbol
        case currency
        case realizedPnl
        case unrealizedPnl
        case shares
        case buyPrice
        case costBasis
        case currentPrice
        case marketValue
        case unrealizedPnlPercent
        case dayChange
        case dayChangePercent
        case weightPercent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(String.self, forKey: .symbol)
        currency = try container.decode(String.self, forKey: .currency)
        realizedPnl = try container.decode(Double.self, forKey: .realizedPnl)
        unrealizedPnl = try container.decode(Double.self, forKey: .unrealizedPnl)
        shares = try container.decodeIfPresent(Double.self, forKey: .shares)
        buyPrice = try container.decodeIfPresent(Double.self, forKey: .buyPrice)
        costBasis = try container.decodeIfPresent(Double.self, forKey: .costBasis)
        currentPrice = try container.decodeIfPresent(Double.self, forKey: .currentPrice)
        marketValue = try container.decodeIfPresent(Double.self, forKey: .marketValue)
        unrealizedPnlPercent = try container.decodeIfPresent(Double.self, forKey: .unrealizedPnlPercent)
        dayChange = try container.decodeIfPresent(Double.self, forKey: .dayChange)
        dayChangePercent = try container.decodeIfPresent(Double.self, forKey: .dayChangePercent)
        weightPercent = try container.decodeIfPresent(Double.self, forKey: .weightPercent)
    }
}

public struct PnlResponse: Codable, Sendable, Equatable {
    public let baseCurrency: String
    public let items: [PnlBySymbol]

    public init(baseCurrency: String, items: [PnlBySymbol]) {
        self.baseCurrency = baseCurrency
        self.items = items
    }
}

public struct DividendProjectedItem: Codable, Sendable, Equatable {
    public let symbol: String
    public let exDividendDate: String
    public let paymentDate: String
    public let amountPerShare: Double
    public let projectedTotal: Double

    public init(
        symbol: String,
        exDividendDate: String,
        paymentDate: String,
        amountPerShare: Double,
        projectedTotal: Double
    ) {
        self.symbol = symbol
        self.exDividendDate = exDividendDate
        self.paymentDate = paymentDate
        self.amountPerShare = amountPerShare
        self.projectedTotal = projectedTotal
    }
}

public struct DividendMonthlyBreakdown: Codable, Sendable, Equatable {
    public let month: String
    public let amount: Double

    public init(month: String, amount: Double) {
        self.month = month
        self.amount = amount
    }
}

public struct PortfolioDividendsResponse: Codable, Sendable, Equatable {
    public let annualProjectedIncome: Double
    public let upcomingDividends: [DividendProjectedItem]
    public let monthlyBreakdown: [DividendMonthlyBreakdown]

    public init(
        annualProjectedIncome: Double,
        upcomingDividends: [DividendProjectedItem],
        monthlyBreakdown: [DividendMonthlyBreakdown]
    ) {
        self.annualProjectedIncome = annualProjectedIncome
        self.upcomingDividends = upcomingDividends
        self.monthlyBreakdown = monthlyBreakdown
    }
}
