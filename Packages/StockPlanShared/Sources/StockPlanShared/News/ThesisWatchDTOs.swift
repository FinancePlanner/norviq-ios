import Foundation

public enum ThesisWatchScope: String, Codable, CaseIterable, Sendable {
    case forYou = "for_you"
    case holdings
    case watchlist
    case sectors
    case market
}

public enum ThesisWatchSeverity: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
}

public enum ThesisWatchEventType: String, Codable, CaseIterable, Sendable {
    case earnings
    case guidance
    case regulation
    case mergerAcquisition = "merger_acquisition"
    case management
    case product
    case capitalReturn = "capital_return"
    case analystAction = "analyst_action"
    case macro
    case legal
    case other
}

public enum ThesisWatchRelationship: String, Codable, CaseIterable, Sendable {
    case holding
    case watchlist
    case market
}

public enum ThesisWatchImpact: String, Codable, CaseIterable, Sendable {
    case supports
    case challenges
    case neutral
    case insufficientEvidence = "insufficient_evidence"
    case notAssessed = "not_assessed"
}

public enum ThesisWatchFeedbackSignal: String, Codable, CaseIterable, Sendable {
    case relevant
    case notRelevant = "not_relevant"
    case supports
    case challenges
    case neutral
    case clear
}

public struct ThesisWatchExposure: Codable, Sendable, Equatable {
    public let currency: String
    public let value: Double
    public let weightPercent: Double

    public init(currency: String, value: Double, weightPercent: Double) {
        self.currency = currency
        self.value = value
        self.weightPercent = weightPercent
    }
}

public struct ThesisWatchCapabilities: Codable, Sendable, Equatable {
    public let isPro: Bool
    public let personalizedRanking: Bool
    public let thesisAnalysis: Bool
    public let pushAlerts: Bool
    public let maxItems: Int

    public init(
        isPro: Bool,
        personalizedRanking: Bool,
        thesisAnalysis: Bool,
        pushAlerts: Bool,
        maxItems: Int
    ) {
        self.isPro = isPro
        self.personalizedRanking = personalizedRanking
        self.thesisAnalysis = thesisAnalysis
        self.pushAlerts = pushAlerts
        self.maxItems = maxItems
    }
}

public struct ThesisWatchStory: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let headline: String
    public let source: String?
    public let url: String
    public let imageUrl: String?
    public let publishedAt: String
    public let providerSummary: String?
    public let summary: String?
    public let whyItMatters: String?
    public let symbols: [String]
    public let sectors: [String]
    public let relationship: ThesisWatchRelationship
    public let eventType: ThesisWatchEventType
    public let severity: ThesisWatchSeverity
    public let exposure: ThesisWatchExposure?
    public let thesisImpact: ThesisWatchImpact
    public let confidence: Double?
    public let feedback: ThesisWatchFeedbackSignal?
    public let isRead: Bool
    public let isDismissed: Bool

    public init(
        id: String,
        headline: String,
        source: String?,
        url: String,
        imageUrl: String?,
        publishedAt: String,
        providerSummary: String?,
        summary: String?,
        whyItMatters: String?,
        symbols: [String],
        sectors: [String],
        relationship: ThesisWatchRelationship,
        eventType: ThesisWatchEventType,
        severity: ThesisWatchSeverity,
        exposure: ThesisWatchExposure?,
        thesisImpact: ThesisWatchImpact,
        confidence: Double?,
        feedback: ThesisWatchFeedbackSignal?,
        isRead: Bool,
        isDismissed: Bool
    ) {
        self.id = id
        self.headline = headline
        self.source = source
        self.url = url
        self.imageUrl = imageUrl
        self.publishedAt = publishedAt
        self.providerSummary = providerSummary
        self.summary = summary
        self.whyItMatters = whyItMatters
        self.symbols = symbols
        self.sectors = sectors
        self.relationship = relationship
        self.eventType = eventType
        self.severity = severity
        self.exposure = exposure
        self.thesisImpact = thesisImpact
        self.confidence = confidence
        self.feedback = feedback
        self.isRead = isRead
        self.isDismissed = isDismissed
    }
}

public struct ThesisWatchFeedResponse: Codable, Sendable, Equatable {
    public let items: [ThesisWatchStory]
    public let nextCursor: String?
    public let generatedAt: String
    public let capabilities: ThesisWatchCapabilities

    public init(
        items: [ThesisWatchStory],
        nextCursor: String?,
        generatedAt: String,
        capabilities: ThesisWatchCapabilities
    ) {
        self.items = items
        self.nextCursor = nextCursor
        self.generatedAt = generatedAt
        self.capabilities = capabilities
    }
}

public struct ThesisWatchFeedbackRequest: Codable, Sendable, Equatable {
    public let signal: ThesisWatchFeedbackSignal

    public init(signal: ThesisWatchFeedbackSignal) {
        self.signal = signal
    }
}

public struct ThesisWatchNotificationPreferences: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let timezone: String
    public let policy: String
    public let dailyCap: Int

    public init(
        enabled: Bool,
        timezone: String,
        policy: String = "thesis_challenges_and_major_events",
        dailyCap: Int = 3
    ) {
        self.enabled = enabled
        self.timezone = timezone
        self.policy = policy
        self.dailyCap = dailyCap
    }
}

public struct UpdateThesisWatchNotificationPreferences: Codable, Sendable, Equatable {
    public let enabled: Bool
    public let timezone: String

    public init(enabled: Bool, timezone: String) {
        self.enabled = enabled
        self.timezone = timezone
    }
}
