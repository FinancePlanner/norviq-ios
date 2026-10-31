import Foundation

// MARK: - Cryptocurrency List

public struct CryptoAssetResponse: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        symbol
    }

    public let symbol: String
    public let name: String
    public let exchange: String?
    public let icoDate: String?
    public let circulatingSupply: Double?
    public let totalSupply: Double?

    public init(
        symbol: String,
        name: String,
        exchange: String? = nil,
        icoDate: String? = nil,
        circulatingSupply: Double? = nil,
        totalSupply: Double? = nil
    ) {
        self.symbol = symbol
        self.name = name
        self.exchange = exchange
        self.icoDate = icoDate
        self.circulatingSupply = circulatingSupply
        self.totalSupply = totalSupply
    }
}

// MARK: - Full Cryptocurrency Quote

public struct CryptoQuoteResponse: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        symbol
    }

    public let symbol: String
    public let name: String
    public let price: Double
    public let changePercentage: Double
    public let change: Double
    public let volume: Double?
    public let dayLow: Double?
    public let dayHigh: Double?
    public let yearHigh: Double?
    public let yearLow: Double?
    public let marketCap: Double?
    public let priceAvg50: Double?
    public let priceAvg200: Double?
    public let exchange: String?
    public let open: Double?
    public let previousClose: Double?
    public let timestamp: Int

    public init(
        symbol: String,
        name: String,
        price: Double,
        changePercentage: Double,
        change: Double,
        volume: Double? = nil,
        dayLow: Double? = nil,
        dayHigh: Double? = nil,
        yearHigh: Double? = nil,
        yearLow: Double? = nil,
        marketCap: Double? = nil,
        priceAvg50: Double? = nil,
        priceAvg200: Double? = nil,
        exchange: String? = nil,
        open: Double? = nil,
        previousClose: Double? = nil,
        timestamp: Int
    ) {
        self.symbol = symbol
        self.name = name
        self.price = price
        self.changePercentage = changePercentage
        self.change = change
        self.volume = volume
        self.dayLow = dayLow
        self.dayHigh = dayHigh
        self.yearHigh = yearHigh
        self.yearLow = yearLow
        self.marketCap = marketCap
        self.priceAvg50 = priceAvg50
        self.priceAvg200 = priceAvg200
        self.exchange = exchange
        self.open = open
        self.previousClose = previousClose
        self.timestamp = timestamp
    }
}

// MARK: - Cryptocurrency Short Quote

public struct CryptoQuoteShortResponse: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        symbol
    }

    public let symbol: String
    public let price: Double
    public let change: Double
    public let volume: Double?

    public init(
        symbol: String,
        price: Double,
        change: Double,
        volume: Double? = nil
    ) {
        self.symbol = symbol
        self.price = price
        self.change = change
        self.volume = volume
    }
}

// MARK: - Historical Light Chart (EOD)

public struct CryptoHistoricalLightPoint: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        "\(symbol)-\(date)"
    }

    public let symbol: String
    public let date: String
    public let price: Double
    public let volume: Double?

    public init(
        symbol: String,
        date: String,
        price: Double,
        volume: Double? = nil
    ) {
        self.symbol = symbol
        self.date = date
        self.price = price
        self.volume = volume
    }
}

// MARK: - Historical Full Chart (EOD)

public struct CryptoHistoricalFullPoint: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        "\(symbol)-\(date)"
    }

    public let symbol: String
    public let date: String
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Double?
    public let change: Double?
    public let changePercent: Double?
    public let vwap: Double?

    public init(
        symbol: String,
        date: String,
        open: Double,
        high: Double,
        low: Double,
        close: Double,
        volume: Double? = nil,
        change: Double? = nil,
        changePercent: Double? = nil,
        vwap: Double? = nil
    ) {
        self.symbol = symbol
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.change = change
        self.changePercent = changePercent
        self.vwap = vwap
    }
}

// MARK: - Intraday Historical Point (1min, 5min, 1hour)

public struct CryptoHistoricalPoint: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        date
    }

    public let date: String
    public let open: Double?
    public let low: Double?
    public let high: Double?
    public let close: Double
    public let volume: Double?

    public init(
        date: String,
        open: Double? = nil,
        low: Double? = nil,
        high: Double? = nil,
        close: Double,
        volume: Double? = nil
    ) {
        self.date = date
        self.open = open
        self.low = low
        self.high = high
        self.close = close
        self.volume = volume
    }
}

// MARK: - Portfolio DTOs

public struct CryptoPortfolioItemRequest: Codable, Sendable, Equatable {
    public let symbol: String
    public let name: String
    public let quantity: Double
    public let averageBuyPrice: Double

    public init(
        symbol: String,
        name: String,
        quantity: Double,
        averageBuyPrice: Double
    ) {
        self.symbol = symbol
        self.name = name
        self.quantity = quantity
        self.averageBuyPrice = averageBuyPrice
    }

    private enum CodingKeys: String, CodingKey {
        case symbol
        case name
        case quantity
        case averageBuyPrice = "average_buy_price"
    }
}

public struct CryptoPortfolioItemResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let symbol: String
    public let name: String
    public let quantity: Double
    public let averageBuyPrice: Double
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        symbol: String,
        name: String,
        quantity: Double,
        averageBuyPrice: Double,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.quantity = quantity
        self.averageBuyPrice = averageBuyPrice
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Watchlist DTOs

public struct CryptoWatchlistItemRequest: Codable, Sendable, Equatable {
    public let symbol: String
    public let name: String
    public let note: String?
    public let status: WatchlistStatus?

    public init(
        symbol: String,
        name: String,
        note: String? = nil,
        status: WatchlistStatus? = nil
    ) {
        self.symbol = symbol
        self.name = name
        self.note = note
        self.status = status
    }
}

public struct CryptoWatchlistItemResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let symbol: String
    public let name: String
    public let note: String?
    public let status: WatchlistStatus
    public let createdAt: String?
    public let updatedAt: String?

    public init(
        id: String,
        symbol: String,
        name: String,
        note: String? = nil,
        status: WatchlistStatus,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.note = note
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
