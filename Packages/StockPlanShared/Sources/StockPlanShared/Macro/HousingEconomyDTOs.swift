import Foundation

// MARK: - Housing hub (`GET /v1/macro/housing`)

/// Country housing snapshot. Null gauges mean lite coverage omitted that field.
public struct HousingHubResponse: Codable, Sendable, Equatable {
    public let country: String
    public let currency: String
    public let asOf: String
    public let updatedAt: String
    public let source: String
    /// Depth tags, e.g. `["hpi", "mortgage", "rent", "starts"]` or `["rent"]`.
    public let coverage: [String]
    public let hpiYoY: MacroIndicatorDTO?
    public let mortgageRate: MacroIndicatorDTO?
    public let rentYoY: MacroIndicatorDTO?
    public let housingStarts: MacroIndicatorDTO?
    public let monthsSupply: MacroIndicatorDTO?
    public let notes: String?

    public init(
        country: String,
        currency: String,
        asOf: String,
        updatedAt: String,
        source: String,
        coverage: [String],
        hpiYoY: MacroIndicatorDTO? = nil,
        mortgageRate: MacroIndicatorDTO? = nil,
        rentYoY: MacroIndicatorDTO? = nil,
        housingStarts: MacroIndicatorDTO? = nil,
        monthsSupply: MacroIndicatorDTO? = nil,
        notes: String? = nil
    ) {
        self.country = country
        self.currency = currency
        self.asOf = asOf
        self.updatedAt = updatedAt
        self.source = source
        self.coverage = coverage
        self.hpiYoY = hpiYoY
        self.mortgageRate = mortgageRate
        self.rentYoY = rentYoY
        self.housingStarts = housingStarts
        self.monthsSupply = monthsSupply
        self.notes = notes
    }
}

// MARK: - Economy / growth hub (`GET /v1/macro/economy`)

/// Labor + GDP + recession-risk snapshot (3-country lite).
public struct EconomyHubResponse: Codable, Sendable, Equatable {
    public let country: String
    public let currency: String
    public let asOf: String
    public let updatedAt: String
    public let source: String
    public let coverage: [String]
    public let unemployment: MacroIndicatorDTO?
    public let gdpGrowth: MacroIndicatorDTO?
    public let payrolls: MacroIndicatorDTO?
    public let initialClaims: MacroIndicatorDTO?
    public let policyRate: MacroIndicatorDTO?
    /// Sahm-rule reading in percentage points (threshold typically 0.50).
    public let sahmRule: MacroIndicatorDTO?
    /// True when official recession dating (e.g. NBER) is active; nil when unavailable.
    public let officialRecession: Bool?
    /// `elevated` | `watch` | `low`
    public let riskLabel: String?
    public let yieldCurveSpread: Double?
    public let notes: String?

    public init(
        country: String,
        currency: String,
        asOf: String,
        updatedAt: String,
        source: String,
        coverage: [String],
        unemployment: MacroIndicatorDTO? = nil,
        gdpGrowth: MacroIndicatorDTO? = nil,
        payrolls: MacroIndicatorDTO? = nil,
        initialClaims: MacroIndicatorDTO? = nil,
        policyRate: MacroIndicatorDTO? = nil,
        sahmRule: MacroIndicatorDTO? = nil,
        officialRecession: Bool? = nil,
        riskLabel: String? = nil,
        yieldCurveSpread: Double? = nil,
        notes: String? = nil
    ) {
        self.country = country
        self.currency = currency
        self.asOf = asOf
        self.updatedAt = updatedAt
        self.source = source
        self.coverage = coverage
        self.unemployment = unemployment
        self.gdpGrowth = gdpGrowth
        self.payrolls = payrolls
        self.initialClaims = initialClaims
        self.policyRate = policyRate
        self.sahmRule = sahmRule
        self.officialRecession = officialRecession
        self.riskLabel = riskLabel
        self.yieldCurveSpread = yieldCurveSpread
        self.notes = notes
    }
}

// MARK: - Policy watch (`GET /v1/macro/policy-watch`)

/// Country-aware central-bank / rates context. Same shape as Fed Watch for US;
/// ECB / Bacen for EA / BR.
public struct PolicyWatchResponse: Codable, Sendable, Equatable {
    public let country: String
    public let asOf: String
    public let updatedAt: String
    public let source: String
    public let institution: String
    public let inflationGauge: MacroIndicatorDTO
    public let inflationTarget: Double
    public let distanceToTarget: Double
    public let policyRate: MacroIndicatorDTO?
    public let treasury2Y: MacroIndicatorDTO?
    public let treasury10Y: MacroIndicatorDTO?
    public let spread10Y2Y: Double?
    public let real10Y: MacroIndicatorDTO?
    public let breakeven10Y: MacroIndicatorDTO?
    public let nextMeeting: FOMCMeetingDTO?
    public let stance: String?
    public let notes: String?

    public init(
        country: String,
        asOf: String,
        updatedAt: String,
        source: String,
        institution: String,
        inflationGauge: MacroIndicatorDTO,
        inflationTarget: Double,
        distanceToTarget: Double,
        policyRate: MacroIndicatorDTO? = nil,
        treasury2Y: MacroIndicatorDTO? = nil,
        treasury10Y: MacroIndicatorDTO? = nil,
        spread10Y2Y: Double? = nil,
        real10Y: MacroIndicatorDTO? = nil,
        breakeven10Y: MacroIndicatorDTO? = nil,
        nextMeeting: FOMCMeetingDTO? = nil,
        stance: String? = nil,
        notes: String? = nil
    ) {
        self.country = country
        self.asOf = asOf
        self.updatedAt = updatedAt
        self.source = source
        self.institution = institution
        self.inflationGauge = inflationGauge
        self.inflationTarget = inflationTarget
        self.distanceToTarget = distanceToTarget
        self.policyRate = policyRate
        self.treasury2Y = treasury2Y
        self.treasury10Y = treasury10Y
        self.spread10Y2Y = spread10Y2Y
        self.real10Y = real10Y
        self.breakeven10Y = breakeven10Y
        self.nextMeeting = nextMeeting
        self.stance = stance
        self.notes = notes
    }
}
