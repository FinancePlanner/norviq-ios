import Foundation

public enum SpendToUnitsSource: String, Codable, Sendable, CaseIterable {
    case preference
    case largestHolding
    case `default`
}

public struct SpendToUnitsCategory: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        title
    }

    public let title: String
    public let overspendAmount: Double
    public let units: Double?

    public init(title: String, overspendAmount: Double, units: Double? = nil) {
        self.title = title
        self.overspendAmount = overspendAmount
        self.units = units
    }
}

public struct SpendToUnitsCapacity: Codable, Sendable, Equatable {
    public let symbol: String
    public let resolvedFrom: SpendToUnitsSource
    public let price: Double?
    public let priceCurrency: String?
    public let quoteAsOf: String?
    public let quoteStale: Bool
    public let surplusAmount: Double
    public let surplusUnits: Double?
    public let currencyCode: String
    public let categories: [SpendToUnitsCategory]
    public let disclaimer: String

    public init(
        symbol: String,
        resolvedFrom: SpendToUnitsSource,
        price: Double? = nil,
        priceCurrency: String? = nil,
        quoteAsOf: String? = nil,
        quoteStale: Bool = false,
        surplusAmount: Double,
        surplusUnits: Double? = nil,
        currencyCode: String,
        categories: [SpendToUnitsCategory] = [],
        disclaimer: String = SpendToUnitsMath.disclaimer
    ) {
        self.symbol = symbol
        self.resolvedFrom = resolvedFrom
        self.price = price
        self.priceCurrency = priceCurrency
        self.quoteAsOf = quoteAsOf
        self.quoteStale = quoteStale
        self.surplusAmount = surplusAmount
        self.surplusUnits = surplusUnits
        self.currencyCode = currencyCode
        self.categories = categories
        self.disclaimer = disclaimer
    }
}

public struct UpdateDcaSymbolRequest: Codable, Sendable, Equatable {
    public let symbol: String

    public init(symbol: String) {
        self.symbol = symbol
    }
}

public enum SpendToUnitsMath {
    public static let defaultSymbol = "VWCE"
    public static let staleQuoteSeconds: TimeInterval = 30 * 60
    public static let disclaimer = "Equivalent at last price. Not an order. Not financial advice."

    public static func normalizeSymbol(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard (1 ... 12).contains(trimmed.count),
              trimmed.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "." || $0 == "-" })
        else { return nil }
        return trimmed
    }

    public static func units(amount: Double, price: Double?) -> Double? {
        guard let price, price > 0, amount.isFinite, price.isFinite else { return nil }
        return (amount / price * 100).rounded() / 100
    }

    public static func surplus(
        investmentContributionTarget: Double,
        lostInvestmentCapital: Double,
        totalTarget: Double,
        totalActual: Double
    ) -> Double {
        if investmentContributionTarget > 0 {
            return max(investmentContributionTarget - lostInvestmentCapital, 0)
        }
        return max(totalTarget - totalActual, 0)
    }
}
