import Foundation

// MARK: - Fed Watch (response for /v1/macro/fed-watch)

/// A single macro indicator reading (rate, yield, or index change).
public struct MacroIndicatorDTO: Codable, Sendable, Equatable {
    public let name: String
    public let value: Double
    public let unit: String // "percent"
    public let asOf: String // "yyyy-MM-dd"
    public let previousValue: Double?
    public let changeFromPrevious: Double?
    public let source: String // e.g. "FRED:PCEPILFE"

    public init(
        name: String,
        value: Double,
        unit: String = "percent",
        asOf: String,
        previousValue: Double? = nil,
        changeFromPrevious: Double? = nil,
        source: String
    ) {
        self.name = name
        self.value = value
        self.unit = unit
        self.asOf = asOf
        self.previousValue = previousValue
        self.changeFromPrevious = changeFromPrevious
        self.source = source
    }
}

/// Probability of a rate move at a FOMC meeting.
public struct RateMoveOddsDTO: Codable, Sendable, Equatable {
    public let move: String // "hold" | "cut25" | "hike25" | ...
    public let probability: Double // 0...1
    public let source: String?

    public init(move: String, probability: Double, source: String? = nil) {
        self.move = move
        self.probability = probability
        self.source = source
    }
}

/// Upcoming FOMC meeting metadata.
public struct FOMCMeetingDTO: Codable, Sendable, Equatable {
    public let startDate: String // "yyyy-MM-dd"
    public let endDate: String
    public let daysRemaining: Int
    public let hasPressConference: Bool?
    public let odds: [RateMoveOddsDTO]?

    public init(
        startDate: String,
        endDate: String,
        daysRemaining: Int,
        hasPressConference: Bool? = nil,
        odds: [RateMoveOddsDTO]? = nil
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.daysRemaining = daysRemaining
        self.hasPressConference = hasPressConference
        self.odds = odds
    }
}

/// Fed Watch box: inflation vs the Fed's 2% target plus bond-market context.
public struct FedWatchResponse: Codable, Sendable, Equatable {
    public let asOf: String
    public let updatedAt: String
    public let source: String
    public let corePCE: MacroIndicatorDTO
    public let fedTarget: Double // 2.0
    public let distanceToTarget: Double // corePCE - fedTarget (pp)
    public let trimmedMeanCPI: MacroIndicatorDTO?
    public let treasury2Y: MacroIndicatorDTO?
    public let treasury10Y: MacroIndicatorDTO?
    public let spread10Y2Y: Double? // pp
    public let real10Y: MacroIndicatorDTO?
    public let breakeven10Y: MacroIndicatorDTO?
    public let nextFOMC: FOMCMeetingDTO?
    public let stance: String? // "restrictive" | "neutral" | "accommodative"
    public let notes: String?

    public init(
        asOf: String,
        updatedAt: String,
        source: String,
        corePCE: MacroIndicatorDTO,
        fedTarget: Double = 2.0,
        distanceToTarget: Double,
        trimmedMeanCPI: MacroIndicatorDTO? = nil,
        treasury2Y: MacroIndicatorDTO? = nil,
        treasury10Y: MacroIndicatorDTO? = nil,
        spread10Y2Y: Double? = nil,
        real10Y: MacroIndicatorDTO? = nil,
        breakeven10Y: MacroIndicatorDTO? = nil,
        nextFOMC: FOMCMeetingDTO? = nil,
        stance: String? = nil,
        notes: String? = nil
    ) {
        self.asOf = asOf
        self.updatedAt = updatedAt
        self.source = source
        self.corePCE = corePCE
        self.fedTarget = fedTarget
        self.distanceToTarget = distanceToTarget
        self.trimmedMeanCPI = trimmedMeanCPI
        self.treasury2Y = treasury2Y
        self.treasury10Y = treasury10Y
        self.spread10Y2Y = spread10Y2Y
        self.real10Y = real10Y
        self.breakeven10Y = breakeven10Y
        self.nextFOMC = nextFOMC
        self.stance = stance
        self.notes = notes
    }
}
