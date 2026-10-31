import Foundation

// MARK: - Badge Type

public enum BadgeType: String, Codable, Sendable, CaseIterable {
    case firstPurchase = "first_purchase"
    case newsReader = "news_reader"
    case investor
    case saver
    case frugalFun = "frugal_fun"
    case spendingDetox = "spending_detox"
    case growthMindset = "growth_mindset"
}

// MARK: - Badge Tier

public enum BadgeTier: String, Codable, Sendable, CaseIterable, Comparable {
    case bronze
    case silver
    case gold

    public static func < (lhs: BadgeTier, rhs: BadgeTier) -> Bool {
        let order: [BadgeTier] = [.bronze, .silver, .gold]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

// MARK: - Earned Tier Info

public struct EarnedTierInfo: Codable, Sendable, Equatable {
    public let tier: BadgeTier
    public let earnedAt: String // ISO 8601

    public init(tier: BadgeTier, earnedAt: String) {
        self.tier = tier
        self.earnedAt = earnedAt
    }
}

// MARK: - Badge Progress Response

public struct BadgeProgressResponse: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        type.rawValue
    }

    public let type: BadgeType
    public let title: String
    public let description: String
    public let iconName: String // SF Symbol placeholder
    public let currentTier: BadgeTier? // nil if no tier earned yet
    public let nextTier: BadgeTier? // nil if gold already earned
    public let progress: Double // 0.0 – 1.0 toward next tier
    public let currentCount: Int // raw progress value
    public let targetCount: Int // target for next tier
    public let earnedTiers: [EarnedTierInfo]

    public init(
        type: BadgeType,
        title: String,
        description: String,
        iconName: String,
        currentTier: BadgeTier?,
        nextTier: BadgeTier?,
        progress: Double,
        currentCount: Int,
        targetCount: Int,
        earnedTiers: [EarnedTierInfo]
    ) {
        self.type = type
        self.title = title
        self.description = description
        self.iconName = iconName
        self.currentTier = currentTier
        self.nextTier = nextTier
        self.progress = progress
        self.currentCount = currentCount
        self.targetCount = targetCount
        self.earnedTiers = earnedTiers
    }
}

// MARK: - Badges List Response

public struct BadgesListResponse: Codable, Sendable, Equatable {
    public let badges: [BadgeProgressResponse]
    public let totalEarnedTiers: Int
    public let totalAvailableTiers: Int

    public init(badges: [BadgeProgressResponse], totalEarnedTiers: Int, totalAvailableTiers: Int) {
        self.badges = badges
        self.totalEarnedTiers = totalEarnedTiers
        self.totalAvailableTiers = totalAvailableTiers
    }
}
