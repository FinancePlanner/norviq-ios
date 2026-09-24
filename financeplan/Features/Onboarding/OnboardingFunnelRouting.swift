import StockPlanShared

/// Where a signed-in user lands. iOS resumes at flow granularity: part of the
/// funnel runs before sign-in, where nothing can be stored on the server.
nonisolated enum OnboardingFunnelRouting {
  /// `repairCompletion` means the device finished the funnel before the server
  /// tracked it (an old-app user whose row is null/null). The caller sends
  /// Home and PATCHes completion, which also stops the web asking again.
  static func route(
    server: OnboardingStateDTO?,
    localRequiresQuestionnaire: Bool,
    localHasImported: Bool,
    hasUserID: Bool
  ) -> (requiresQuestionnaire: Bool, requiresImport: Bool, repairCompletion: Bool) {
    guard let server else {
      return (localRequiresQuestionnaire, !hasUserID || !localHasImported, false)
    }
    if server.funnelCompletedAt != nil {
      return (false, false, false)
    }
    if server.funnelStep == nil, localHasImported, !localRequiresQuestionnaire {
      return (false, false, true)
    }
    let step = server.funnelStep.flatMap(OnboardingFunnelStep.init(rawValue:))
    let owesPaywall = step == .questionnaire || step == .paywall || (step == nil && localRequiresQuestionnaire)
    return (owesPaywall, true, false)
  }
}

/// `onboarding_funnel_resumed` fires at most once per app session, however
/// often the app re-reads onboarding state (sign-in, foreground, token refresh).
@MainActor
final class FunnelResumedOnce {
  static let shared = FunnelResumedOnce()

  private var sent = false

  /// True the first time only.
  func take() -> Bool {
    guard !sent else { return false }
    sent = true
    return true
  }
}
