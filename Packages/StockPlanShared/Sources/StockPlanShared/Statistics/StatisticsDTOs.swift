import Foundation

public struct StatisticsDTO: Codable, Sendable, Equatable {
    public let generatedAt: String
    public let importedStocks: ImportedStocksStatisticsDTO
    public let watchlist: WatchlistStatisticsDTO
    public let looklist: LooklistStatisticsDTO
    public let market: MarketStatisticsDTO

    public init(
        generatedAt: String,
        importedStocks: ImportedStocksStatisticsDTO,
        watchlist: WatchlistStatisticsDTO,
        looklist: LooklistStatisticsDTO,
        market: MarketStatisticsDTO
    ) {
        self.generatedAt = generatedAt
        self.importedStocks = importedStocks
        self.watchlist = watchlist
        self.looklist = looklist
        self.market = market
    }
}

public typealias StatisticsResponse = StatisticsDTO

public struct ImportedStocksStatisticsDTO: Codable, Sendable, Equatable {
    public let totalPositions: Int
    public let totalMarketValue: Double
    public let totalCostBasis: Double
    public let totalUnrealizedPnl: Double
    public let totalRealizedPnl: Double
    public let stockSummaries: [StockStatisticsSummaryDTO]
    public let stockAllocations: [StockAllocationDTO]
    public let sectorAllocations: [SectorAllocationDTO]
    public let calendarPerformance: [CalendarPerformanceDTO]

    public init(
        totalPositions: Int,
        totalMarketValue: Double,
        totalCostBasis: Double,
        totalUnrealizedPnl: Double,
        totalRealizedPnl: Double,
        stockSummaries: [StockStatisticsSummaryDTO],
        stockAllocations: [StockAllocationDTO],
        sectorAllocations: [SectorAllocationDTO],
        calendarPerformance: [CalendarPerformanceDTO]
    ) {
        self.totalPositions = totalPositions
        self.totalMarketValue = totalMarketValue
        self.totalCostBasis = totalCostBasis
        self.totalUnrealizedPnl = totalUnrealizedPnl
        self.totalRealizedPnl = totalRealizedPnl
        self.stockSummaries = stockSummaries
        self.stockAllocations = stockAllocations
        self.sectorAllocations = sectorAllocations
        self.calendarPerformance = calendarPerformance
    }
}

public struct StockStatisticsSummaryDTO: Codable, Sendable, Equatable {
    public let symbol: String
    public let marketValue: Double
    public let weightPercent: Double
    public let dailyChangePercent: Double?
    public let weeklyChangePercent: Double?
    public let monthlyChangePercent: Double?
    public let unrealizedPnl: Double

    public init(
        symbol: String,
        marketValue: Double,
        weightPercent: Double,
        dailyChangePercent: Double? = nil,
        weeklyChangePercent: Double? = nil,
        monthlyChangePercent: Double? = nil,
        unrealizedPnl: Double
    ) {
        self.symbol = symbol
        self.marketValue = marketValue
        self.weightPercent = weightPercent
        self.dailyChangePercent = dailyChangePercent
        self.weeklyChangePercent = weeklyChangePercent
        self.monthlyChangePercent = monthlyChangePercent
        self.unrealizedPnl = unrealizedPnl
    }
}

public struct StockAllocationDTO: Codable, Sendable, Equatable, Identifiable {
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

public struct SectorAllocationDTO: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        sector
    }

    public let sector: String
    public let value: Double
    public let weightPercent: Double

    public init(sector: String, value: Double, weightPercent: Double) {
        self.sector = sector
        self.value = value
        self.weightPercent = weightPercent
    }
}

public struct CalendarPerformanceDTO: Codable, Sendable, Equatable {
    public let date: String
    public let pnl: Double
    public let pnlPercent: Double
    public let isUpDay: Bool

    public init(date: String, pnl: Double, pnlPercent: Double, isUpDay: Bool) {
        self.date = date
        self.pnl = pnl
        self.pnlPercent = pnlPercent
        self.isUpDay = isUpDay
    }
}

public struct WatchlistStatisticsDTO: Codable, Sendable, Equatable {
    public let totalSymbols: Int
    public let symbolsWithNotes: Int
    public let sectorAllocations: [SectorAllocationDTO]
    public let topWatched: [WatchlistSymbolDTO]

    public init(
        totalSymbols: Int,
        symbolsWithNotes: Int,
        sectorAllocations: [SectorAllocationDTO],
        topWatched: [WatchlistSymbolDTO]
    ) {
        self.totalSymbols = totalSymbols
        self.symbolsWithNotes = symbolsWithNotes
        self.sectorAllocations = sectorAllocations
        self.topWatched = topWatched
    }
}

public struct WatchlistSymbolDTO: Codable, Sendable, Equatable {
    public let symbol: String
    public let mentionCount: Int

    public init(symbol: String, mentionCount: Int) {
        self.symbol = symbol
        self.mentionCount = mentionCount
    }
}

public struct LooklistStatisticsDTO: Codable, Sendable, Equatable {
    public let totalIdeas: Int
    public let activeIdeas: Int
    public let ideasWithTarget: Int
    public let ideasByConviction: [LooklistConvictionDTO]

    public init(
        totalIdeas: Int,
        activeIdeas: Int,
        ideasWithTarget: Int,
        ideasByConviction: [LooklistConvictionDTO]
    ) {
        self.totalIdeas = totalIdeas
        self.activeIdeas = activeIdeas
        self.ideasWithTarget = ideasWithTarget
        self.ideasByConviction = ideasByConviction
    }
}

public struct LooklistConvictionDTO: Codable, Sendable, Equatable {
    public let conviction: String
    public let count: Int

    public init(conviction: String, count: Int) {
        self.conviction = conviction
        self.count = count
    }
}

public struct MarketStatisticsDTO: Codable, Sendable, Equatable {
    public let benchmarkSymbol: String
    public let benchmarkChange1D: Double?
    public let benchmarkChange1W: Double?
    public let benchmarkChange1M: Double?
    public let benchmarkChangeYtd: Double?
    public let heatmap: [MarketHeatmapDTO]

    public init(
        benchmarkSymbol: String,
        benchmarkChange1D: Double? = nil,
        benchmarkChange1W: Double? = nil,
        benchmarkChange1M: Double? = nil,
        benchmarkChangeYtd: Double? = nil,
        heatmap: [MarketHeatmapDTO]
    ) {
        self.benchmarkSymbol = benchmarkSymbol
        self.benchmarkChange1D = benchmarkChange1D
        self.benchmarkChange1W = benchmarkChange1W
        self.benchmarkChange1M = benchmarkChange1M
        self.benchmarkChangeYtd = benchmarkChangeYtd
        self.heatmap = heatmap
    }
}

public struct MarketHeatmapDTO: Codable, Sendable, Equatable {
    public let symbol: String
    public let changePercent: Double

    public init(symbol: String, changePercent: Double) {
        self.symbol = symbol
        self.changePercent = changePercent
    }
}
