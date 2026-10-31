import Foundation

public struct BillingContextResponse: Codable, Sendable, Equatable {
    public let plan: String
    public let entitlementLevel: String
    public let isPro: Bool
    public let isPremium: Bool
    public let subscription: BillingSubscriptionDTO?
    public let planOptions: [BillingPlanOptionDTO]
    public let features: [BillingFeatureDTO]
    public let usage: [BillingUsageDTO]
    public let trialDaysRemaining: Int?
    public let isTrialActive: Bool
    /// True when the user previously had a free trial that has now ended and they
    /// are not currently entitled. Drives the "trial ended → subscribe" surfaces.
    /// Distinguishes an expired-trial user from a never-trialed free user.
    public let trialExpired: Bool
    public let generatedAt: Date

    public init(
        plan: String,
        entitlementLevel: String,
        isPro: Bool? = nil,
        isPremium: Bool,
        subscription: BillingSubscriptionDTO?,
        planOptions: [BillingPlanOptionDTO] = [],
        features: [BillingFeatureDTO],
        usage: [BillingUsageDTO],
        trialDaysRemaining: Int? = nil,
        isTrialActive: Bool = false,
        trialExpired: Bool = false,
        generatedAt: Date
    ) {
        self.plan = plan
        self.entitlementLevel = entitlementLevel
        self.isPro = isPro ?? isPremium
        self.isPremium = isPremium
        self.subscription = subscription
        self.planOptions = planOptions
        self.features = features
        self.usage = usage
        self.trialDaysRemaining = trialDaysRemaining
        self.isTrialActive = isTrialActive
        self.trialExpired = trialExpired
        self.generatedAt = generatedAt
    }

    enum CodingKeys: String, CodingKey {
        case plan
        case entitlementLevel
        case isPro
        case isPremium
        case subscription
        case planOptions
        case features
        case usage
        case trialDaysRemaining
        case isTrialActive
        case trialExpired
        case generatedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        plan = try container.decode(String.self, forKey: .plan)
        entitlementLevel = try container.decode(String.self, forKey: .entitlementLevel)
        isPremium = try container.decode(Bool.self, forKey: .isPremium)
        isPro = try container.decodeIfPresent(Bool.self, forKey: .isPro) ?? isPremium
        subscription = try container.decodeIfPresent(BillingSubscriptionDTO.self, forKey: .subscription)
        planOptions = try container.decodeIfPresent([BillingPlanOptionDTO].self, forKey: .planOptions) ?? []
        features = try container.decode([BillingFeatureDTO].self, forKey: .features)
        usage = try container.decode([BillingUsageDTO].self, forKey: .usage)
        trialDaysRemaining = try container.decodeIfPresent(Int.self, forKey: .trialDaysRemaining)
        isTrialActive = try container.decodeIfPresent(Bool.self, forKey: .isTrialActive) ?? false
        trialExpired = try container.decodeIfPresent(Bool.self, forKey: .trialExpired) ?? false
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
    }
}

public struct BillingPlanOptionDTO: Codable, Sendable, Equatable {
    public let productId: String
    public let plan: String
    public let displayName: String
    public let interval: String
    public let rank: Int
    public let badge: String?
    public let isCurrent: Bool
    public let changeKind: String

    public init(
        productId: String,
        plan: String,
        displayName: String,
        interval: String,
        rank: Int,
        badge: String?,
        isCurrent: Bool,
        changeKind: String
    ) {
        self.productId = productId
        self.plan = plan
        self.displayName = displayName
        self.interval = interval
        self.rank = rank
        self.badge = badge
        self.isCurrent = isCurrent
        self.changeKind = changeKind
    }
}

public struct BillingSubscriptionDTO: Codable, Sendable, Equatable {
    public let provider: String
    public let store: String?
    public let productId: String
    public let plan: String
    public let status: String
    public let periodStartedAt: Date?
    public let periodEndsAt: Date?
    public let trialEndsAt: Date?
    public let gracePeriodEndsAt: Date?
    public let cancelledAt: Date?
    public let isTrial: Bool
    public let isInGracePeriod: Bool
    public let hasBillingIssue: Bool
    public let isCancelledButActive: Bool
    public let renewsOrExpiresAt: Date?
    public let willRenew: Bool?
    public let accessEndsAt: Date?
    public let pendingProductId: String?
    public let pendingPlan: String?
    public let pendingPlanEffectiveAt: Date?

    public init(
        provider: String,
        store: String? = nil,
        productId: String,
        plan: String,
        status: String,
        periodStartedAt: Date?,
        periodEndsAt: Date?,
        trialEndsAt: Date?,
        gracePeriodEndsAt: Date?,
        cancelledAt: Date?,
        isTrial: Bool,
        isInGracePeriod: Bool,
        hasBillingIssue: Bool,
        isCancelledButActive: Bool,
        renewsOrExpiresAt: Date?,
        willRenew: Bool? = nil,
        accessEndsAt: Date? = nil,
        pendingProductId: String? = nil,
        pendingPlan: String? = nil,
        pendingPlanEffectiveAt: Date? = nil
    ) {
        self.provider = provider
        self.store = store
        self.productId = productId
        self.plan = plan
        self.status = status
        self.periodStartedAt = periodStartedAt
        self.periodEndsAt = periodEndsAt
        self.trialEndsAt = trialEndsAt
        self.gracePeriodEndsAt = gracePeriodEndsAt
        self.cancelledAt = cancelledAt
        self.isTrial = isTrial
        self.isInGracePeriod = isInGracePeriod
        self.hasBillingIssue = hasBillingIssue
        self.isCancelledButActive = isCancelledButActive
        self.renewsOrExpiresAt = renewsOrExpiresAt
        self.willRenew = willRenew
        self.accessEndsAt = accessEndsAt
        self.pendingProductId = pendingProductId
        self.pendingPlan = pendingPlan
        self.pendingPlanEffectiveAt = pendingPlanEffectiveAt
    }
}

public struct BillingFeatureDTO: Codable, Sendable, Equatable {
    public let key: String
    public let title: String
    public let available: Bool
    public let requiredPlan: String?
    public let reason: String?
    public let limit: Int?
    public let used: Int?
    public let remaining: Int?

    public init(
        key: String,
        title: String,
        available: Bool,
        requiredPlan: String?,
        reason: String?,
        limit: Int?,
        used: Int?,
        remaining: Int?
    ) {
        self.key = key
        self.title = title
        self.available = available
        self.requiredPlan = requiredPlan
        self.reason = reason
        self.limit = limit
        self.used = used
        self.remaining = remaining
    }
}

public struct BillingUsageDTO: Codable, Sendable, Equatable {
    public let key: String
    public let used: Int
    public let limit: Int?
    public let remaining: Int?
    public let periodStart: Date?

    public init(
        key: String,
        used: Int,
        limit: Int?,
        remaining: Int?,
        periodStart: Date?
    ) {
        self.key = key
        self.used = used
        self.limit = limit
        self.remaining = remaining
        self.periodStart = periodStart
    }
}

public struct BillingUpgradeRequiredResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let code: String
    public let error: String
    public let feature: String
    public let plan: String
    public let requiredPlan: String
    public let limit: Int?
    public let current: Int?

    public init(
        success: Bool,
        code: String,
        error: String,
        feature: String,
        plan: String,
        requiredPlan: String,
        limit: Int?,
        current: Int?
    ) {
        self.success = success
        self.code = code
        self.error = error
        self.feature = feature
        self.plan = plan
        self.requiredPlan = requiredPlan
        self.limit = limit
        self.current = current
    }
}
