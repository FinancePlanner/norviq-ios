import SwiftUI

/// Something that asks the shell to go somewhere: a deep link, a push, a card.
nonisolated enum NavigationRequest: Equatable, Sendable {
  case stock(symbol: String)
  case portfolio(automation: String?)
  case tax
  case budget
  case thesisWatch
  case social(inviteCode: String?, section: String?)
  case boardPost
  case groups
  case marketBrief
  case crypto
  case reports
  case insights
  case settings
}

/// A tab plus the screens pushed on top of its root.
nonisolated struct NavigationTarget: Equatable, Sendable {
  let tab: AppTab
  let path: [AppDestination]
}

/// The one place that maps a request to a tab and a path. It decides only
/// where to land; side effects (pending symbol, boards viewer, brief router,
/// pending groups link) stay with the caller.
nonisolated enum NavigationResolver {
  /// - Returns: `nil` when the request needs a feature that is switched off.
  static func target(
    for request: NavigationRequest, groupsEnabled: Bool, socialEnabled: Bool
  ) -> NavigationTarget? {
    switch request {
    case .stock, .portfolio, .thesisWatch:
      NavigationTarget(tab: .wealth, path: [])
    case .crypto:
      NavigationTarget(tab: .wealth, path: [.crypto])
    case .budget:
      NavigationTarget(tab: .money, path: [])
    case .tax:
      NavigationTarget(tab: .plan, path: [.tax])
    case .marketBrief:
      NavigationTarget(tab: .today, path: [])
    case .social:
      socialEnabled ? NavigationTarget(tab: .more, path: [.friends]) : nil
    case .groups:
      groupsEnabled ? NavigationTarget(tab: .more, path: [.groups]) : nil
    case .boardPost:
      NavigationTarget(tab: .more, path: [.boards])
    case .reports:
      NavigationTarget(tab: .more, path: [.reports])
    case .insights:
      NavigationTarget(tab: .more, path: [.insights])
    case .settings:
      NavigationTarget(tab: .more, path: [.settings])
    }
  }
}

nonisolated extension NavigationTarget {
  /// The tab's path once this target lands on it, `current` being what is
  /// open there now. Whatever else is open is replaced, but a tab already on
  /// the target keeps what sits above it: Groups and Friends take their
  /// pending link from there, and Groups moves its own part of the path.
  /// Replacing it would pop the open group mid-link.
  func path(replacing current: NavigationPath) -> NavigationPath {
    let landing = NavigationPath(path)
    guard !path.isEmpty, current.count >= path.count else { return landing }
    var base = current
    base.removeLast(current.count - path.count)
    return base == landing ? current : landing
  }
}
