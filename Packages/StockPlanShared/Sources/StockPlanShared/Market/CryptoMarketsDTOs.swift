import Foundation

// MARK: - /v1/crypto/markets

/// Performance window for the crypto markets view. Raw values are the
/// `timeframe` query parameter.
public enum CryptoMarketsTimeframe: String, Codable, Sendable, CaseIterable {
    case oneDay = "1d"
    case oneWeek = "1w"
    /// Rolling 30 days, not month-to-date.
    case oneMonth = "1m"
    case yearToDate = "ytd"
    case oneYear = "1y"
    /// Distance from the all-time high.
    case allTime = "all"

    public var displayTitle: String {
        switch self {
        case .oneDay: "1D"
        case .oneWeek: "1W"
        case .oneMonth: "1M"
        case .yearToDate: "YTD"
        case .oneYear: "1Y"
        case .allTime: "All"
        }
    }
}

/// How clients colour a coin. `change` is a diverging scale around zero
/// (±`colorScaleMaxPct`); `athDistance` runs from `-colorScaleMaxPct` (deep
/// drawdown) up to 0 (at the high).
public enum CryptoMarketsColorMode: String, Codable, Sendable {
    case change
    case athDistance
}

/// Percentage change per window. Nil when the source cannot provide it.
public struct CryptoTimeframeReturns: Codable, Sendable, Equatable {
    public let oneDay: Double?
    public let oneWeek: Double?
    public let oneMonth: Double?
    public let yearToDate: Double?
    public let oneYear: Double?

    enum CodingKeys: String, CodingKey {
        case oneDay = "1d"
        case oneWeek = "1w"
        case oneMonth = "1m"
        case yearToDate = "ytd"
        case oneYear = "1y"
    }

    public init(
        oneDay: Double? = nil,
        oneWeek: Double? = nil,
        oneMonth: Double? = nil,
        yearToDate: Double? = nil,
        oneYear: Double? = nil
    ) {
        self.oneDay = oneDay
        self.oneWeek = oneWeek
        self.oneMonth = oneMonth
        self.yearToDate = yearToDate
        self.oneYear = oneYear
    }

    /// The return for a window. `.allTime` is not a return; read
    /// `CryptoMarketCoin.athChangePct` instead.
    public func value(for timeframe: CryptoMarketsTimeframe) -> Double? {
        switch timeframe {
        case .oneDay: oneDay
        case .oneWeek: oneWeek
        case .oneMonth: oneMonth
        case .yearToDate: yearToDate
        case .oneYear: oneYear
        case .allTime: nil
        }
    }
}

public struct CryptoMarketCoin: Codable, Sendable, Equatable, Identifiable {
    /// Provider id (e.g. CoinGecko `bitcoin`). Stable and unique.
    public let id: String
    /// Ticker, upper-cased (e.g. `BTC`). Not guaranteed unique across providers.
    public let symbol: String
    /// FMP symbol (e.g. `BTCUSD`) when FMP carries the coin; nil disables the
    /// detail link, since detail charts come from FMP history.
    public let fmpSymbol: String?
    public let name: String
    public let imageUrl: String?
    public let rank: Int?
    public let sector: String
    public let price: Double
    public let marketCap: Double?
    public let volume24h: Double?
    /// Value for the response's timeframe: a return, or for `.allTime` the
    /// distance from the all-time high.
    public let changePct: Double?
    public let returns: CryptoTimeframeReturns
    public let ath: Double?
    public let athChangePct: Double?
    /// ISO 8601.
    public let athDate: String?
    public let atl: Double?
    public let atlChangePct: Double?
    /// ISO 8601.
    public let atlDate: String?
    /// Last 7 days of prices, oldest first, downsampled.
    public let sparkline7d: [Double]

    public init(
        id: String,
        symbol: String,
        fmpSymbol: String? = nil,
        name: String,
        imageUrl: String? = nil,
        rank: Int? = nil,
        sector: String,
        price: Double,
        marketCap: Double? = nil,
        volume24h: Double? = nil,
        changePct: Double? = nil,
        returns: CryptoTimeframeReturns = .init(),
        ath: Double? = nil,
        athChangePct: Double? = nil,
        athDate: String? = nil,
        atl: Double? = nil,
        atlChangePct: Double? = nil,
        atlDate: String? = nil,
        sparkline7d: [Double] = []
    ) {
        self.id = id
        self.symbol = symbol
        self.fmpSymbol = fmpSymbol
        self.name = name
        self.imageUrl = imageUrl
        self.rank = rank
        self.sector = sector
        self.price = price
        self.marketCap = marketCap
        self.volume24h = volume24h
        self.changePct = changePct
        self.returns = returns
        self.ath = ath
        self.athChangePct = athChangePct
        self.athDate = athDate
        self.atl = atl
        self.atlChangePct = atlChangePct
        self.atlDate = atlDate
        self.sparkline7d = sparkline7d
    }
}

public struct CryptoMarketsSummary: Codable, Sendable, Equatable {
    /// Includes stablecoins, which are excluded from every list.
    public let totalMarketCap: Double?
    public let btcDominancePct: Double?
    /// Coins up / down over the response's timeframe.
    public let advancers: Int
    public let decliners: Int

    public init(totalMarketCap: Double?, btcDominancePct: Double?, advancers: Int, decliners: Int) {
        self.totalMarketCap = totalMarketCap
        self.btcDominancePct = btcDominancePct
        self.advancers = advancers
        self.decliners = decliners
    }
}

/// Independent of the requested timeframe.
public struct CryptoAthBoard: Codable, Sendable, Equatable {
    /// New all-time high within the last 30 days, newest first.
    public let recentAths: [CryptoMarketCoin]
    /// Closest to their all-time high.
    public let nearAth: [CryptoMarketCoin]
    /// Furthest below their all-time high.
    public let deepestDrawdowns: [CryptoMarketCoin]

    public init(recentAths: [CryptoMarketCoin], nearAth: [CryptoMarketCoin], deepestDrawdowns: [CryptoMarketCoin]) {
        self.recentAths = recentAths
        self.nearAth = nearAth
        self.deepestDrawdowns = deepestDrawdowns
    }
}

/// One payload serves bubbles, performers, the heatmap and the ATH board.
public struct CryptoMarketsResponse: Codable, Sendable, Equatable {
    public let timeframe: CryptoMarketsTimeframe
    /// Windows the current source can answer; clients disable the rest.
    public let supportedTimeframes: [CryptoMarketsTimeframe]
    public let source: String
    /// ISO 8601 time of the underlying snapshot.
    public let asOf: String
    /// True when served from the fallback cache after a failed refresh.
    public let isStale: Bool
    public let colorMode: CryptoMarketsColorMode
    public let colorScaleMaxPct: Double
    /// Credit line the data source requires to be shown, if any.
    public let attribution: String?
    public let summary: CryptoMarketsSummary
    /// Ranked by market cap.
    public let coins: [CryptoMarketCoin]
    public let gainers: [CryptoMarketCoin]
    public let losers: [CryptoMarketCoin]
    public let athBoard: CryptoAthBoard

    public init(
        timeframe: CryptoMarketsTimeframe,
        supportedTimeframes: [CryptoMarketsTimeframe],
        source: String,
        asOf: String,
        isStale: Bool,
        colorMode: CryptoMarketsColorMode,
        colorScaleMaxPct: Double,
        attribution: String?,
        summary: CryptoMarketsSummary,
        coins: [CryptoMarketCoin],
        gainers: [CryptoMarketCoin],
        losers: [CryptoMarketCoin],
        athBoard: CryptoAthBoard
    ) {
        self.timeframe = timeframe
        self.supportedTimeframes = supportedTimeframes
        self.source = source
        self.asOf = asOf
        self.isStale = isStale
        self.colorMode = colorMode
        self.colorScaleMaxPct = colorScaleMaxPct
        self.attribution = attribution
        self.summary = summary
        self.coins = coins
        self.gainers = gainers
        self.losers = losers
        self.athBoard = athBoard
    }
}
