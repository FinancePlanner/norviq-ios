import StockPlanShared

/// Where a signed-in user lands. iOS resumes at flow granularity: part of the
/// funnel runs before sign-in, where nothing can be stored on the server.
nonisolated enum OnboardingFunnelRouting {
  static func route(
    server: OnboardingStateDTO?,
    localRequiresQuestionnaire: Bool,
    localHasImported: Bool,
    hasUserID: Bool
  ) -> (requiresQuestionnaire: Bool, requiresImport: Bool) {
    guard let server else {
      return (localRequiresQuestionnaire, !hasUserID || !localHasImported)
    }
    if server.funnelCompletedAt != nil {
      return (false, false)
    }
    let step = server.funnelStep.flatMap(OnboardingFunnelStep.init(rawValue:))
    let owesPaywall = localRequiresQuestionnaire || step == .questionnaire || step == .paywall
    return (owesPaywall, true)
  }
}
