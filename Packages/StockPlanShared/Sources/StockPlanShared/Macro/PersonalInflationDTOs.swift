import Foundation

/// A spending-weighted estimate of the inflation a household is experiencing.
///
/// The backend derives this from the user's recorded expenses and the official
/// inflation components available for the requested country. `coveragePercent`
/// makes the estimate's data quality explicit when some spending categories
/// cannot be mapped to a published inflation component.
public struct PersonalInflationResponse: Codable, Sendable, Equatable {
    public let country: String
    public let currency: String
    public let asOf: String
    public let periodMonths: Int
    public let sampleStart: String
    public let sampleEnd: String
    public let personalRate: Double?
    public let officialRate: Double
    public let difference: Double?
    public let averageMonthlySpend: Double
    public let estimatedAnnualImpact: Double?
    public let coveragePercent: Double
    public let mappedSpend: Double
    public let totalSpend: Double
    public let expenseCount: Int
    public let method: String
    public let source: String
    public let components: [PersonalInflationComponentDTO]

    public init(
        country: String,
        currency: String,
        asOf: String,
        periodMonths: Int,
        sampleStart: String,
        sampleEnd: String,
        personalRate: Double? = nil,
        officialRate: Double,
        difference: Double? = nil,
        averageMonthlySpend: Double,
        estimatedAnnualImpact: Double? = nil,
        coveragePercent: Double,
        mappedSpend: Double,
        totalSpend: Double,
        expenseCount: Int,
        method: String,
        source: String,
        components: [PersonalInflationComponentDTO]
    ) {
        self.country = country
        self.currency = currency
        self.asOf = asOf
        self.periodMonths = periodMonths
        self.sampleStart = sampleStart
        self.sampleEnd = sampleEnd
        self.personalRate = personalRate
        self.officialRate = officialRate
        self.difference = difference
        self.averageMonthlySpend = averageMonthlySpend
        self.estimatedAnnualImpact = estimatedAnnualImpact
        self.coveragePercent = coveragePercent
        self.mappedSpend = mappedSpend
        self.totalSpend = totalSpend
        self.expenseCount = expenseCount
        self.method = method
        self.source = source
        self.components = components
    }
}

public struct PersonalInflationComponentDTO: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        category
    }

    public let category: String
    public let macroCategory: String
    public let spend: Double
    public let weight: Double
    public let inflationRate: Double
    public let contribution: Double
    public let expenseCount: Int

    public init(
        category: String,
        macroCategory: String,
        spend: Double,
        weight: Double,
        inflationRate: Double,
        contribution: Double,
        expenseCount: Int
    ) {
        self.category = category
        self.macroCategory = macroCategory
        self.spend = spend
        self.weight = weight
        self.inflationRate = inflationRate
        self.contribution = contribution
        self.expenseCount = expenseCount
    }
}
