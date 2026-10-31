import Foundation

// Server-owned onboarding progress. The contract is docs/guided-start.md.

/// Where a user is in the first-run funnel. Carried on the wire as a string so
/// an older client never fails to decode a step a newer one wrote.
public enum OnboardingFunnelStep: String, Codable, Sendable, CaseIterable {
    case questionnaire
    case paywall
    case welcome
    case `import`
    case budget
    case done
}

public struct OnboardingStateDTO: Codable, Sendable, Equatable {
    public let funnelStep: String?
    public let funnelCompletedAt: Date?
    public let addHoldingCompleted: Bool
    public let firstHoldingAt: Date?
    public let setBudgetCompleted: Bool
    public let firstBudgetAt: Date?
    public let setGoalCompleted: Bool
    public let firstGoalAt: Date?
    public let guidedStartDismissedAt: Date?

    public init(
        funnelStep: String? = nil,
        funnelCompletedAt: Date? = nil,
        addHoldingCompleted: Bool = false,
        firstHoldingAt: Date? = nil,
        setBudgetCompleted: Bool = false,
        firstBudgetAt: Date? = nil,
        setGoalCompleted: Bool = false,
        firstGoalAt: Date? = nil,
        guidedStartDismissedAt: Date? = nil
    ) {
        self.funnelStep = funnelStep
        self.funnelCompletedAt = funnelCompletedAt
        self.addHoldingCompleted = addHoldingCompleted
        self.firstHoldingAt = firstHoldingAt
        self.setBudgetCompleted = setBudgetCompleted
        self.firstBudgetAt = firstBudgetAt
        self.setGoalCompleted = setGoalCompleted
        self.firstGoalAt = firstGoalAt
        self.guidedStartDismissedAt = guidedStartDismissedAt
    }
}

/// The only fields a client may write. Guided-start latches are absent on
/// purpose: the server sets them as a side effect of the real action.
public struct OnboardingPatchRequest: Codable, Sendable, Equatable {
    public let funnelStep: String?
    /// One-way. The server rejects `false`.
    public let funnelCompleted: Bool?
    public let guidedStartDismissed: Bool?

    public init(funnelStep: String? = nil, funnelCompleted: Bool? = nil, guidedStartDismissed: Bool? = nil) {
        self.funnelStep = funnelStep
        self.funnelCompleted = funnelCompleted
        self.guidedStartDismissed = guidedStartDismissed
    }
}
