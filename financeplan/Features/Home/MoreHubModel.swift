import Foundation

/// What a hub row does when it is tapped.
nonisolated enum HubAction: Equatable, Sendable {
  /// Push onto the hub's own stack.
  case push(AppDestination)
  /// Leave the hub for another tab, which handles the request. Market brief
  /// is a card on Today, not a screen of its own.
  case selectTab(AppTab, NavigationRequest)
}

/// The outcome of a tap, once the user's entitlement is known.
nonisolated enum HubTap: Equatable, Sendable {
  /// A Pro row tapped by a free user: the paywall, over the hub.
  case paywall
  case perform(HubAction)
}

/// One row of the More or Plan hub. Names are the destination table's.
nonisolated struct HubRow: Identifiable, Equatable, Sendable {
  let id: String
  let title: LocalizedStringResource
  /// Monochrome, outline SF Symbol.
  let systemImage: String
  let value: String?
  let isPro: Bool
  let action: HubAction

  init(
    id: String, title: LocalizedStringResource, systemImage: String, value: String? = nil, isPro: Bool = false,
    action: HubAction
  ) {
    self.id = id
    self.title = title
    self.systemImage = systemImage
    self.value = value
    self.isPro = isPro
    self.action = action
  }

  /// A free user on a Pro row gets the paywall in place; the tab never changes.
  func tap(userIsPro: Bool) -> HubTap {
    isPro && !userIsPro ? .paywall : .perform(action)
  }
}

nonisolated struct HubSection: Identifiable, Equatable, Sendable {
  let id: String
  let title: LocalizedStringResource
  let rows: [HubRow]
}

/// The account row at the top of More: who is signed in.
nonisolated struct HubAccount: Equatable, Sendable {
  /// `nil` while the profile is unknown; the row then reads "Account".
  let name: String?
  let initial: String
}

/// More (spec §7.10): Intelligence, Community, Account. Gated rows are left
/// out, never shown disabled.
nonisolated enum MoreHubModel {
  /// `groupsBadge` and `friendsBadge` are the counts the More tab badge adds
  /// up, so each one shows on its own row.
  static func sections(
    social: SocialConfig, groupsBadge: Int, friendsBadge: Int, locale: Locale = .current
  ) -> [HubSection] {
    func newCount(_ count: Int) -> String? {
      count > 0 ? String(localized: LocalizedStringResource("\(count) new", locale: locale)) : nil
    }
    var community: [HubRow] = []
    if social.groupsEnabled {
      community.append(
        HubRow(
          id: "groups", title: "Groups", systemImage: "bubble.left.and.bubble.right",
          value: newCount(groupsBadge), action: .push(.groups)))
    }
    if social.enabled {
      community.append(
        HubRow(
          id: "friends", title: "Friends", systemImage: "person.2", value: newCount(friendsBadge),
          action: .push(.friends)))
    }
    // Boards needs no switch, so Community is never empty.
    community.append(
      HubRow(id: "boards", title: "Boards", systemImage: "bubble.left.and.text.bubble.right", action: .push(.boards)))

    return [
      HubSection(
        id: "intelligence", title: "Intelligence",
        rows: [
          HubRow(
            id: "marketBrief", title: "Market brief", systemImage: "newspaper",
            action: .selectTab(.today, .marketBrief)),
          HubRow(id: "markets", title: "Markets", systemImage: "square.grid.3x3", action: .push(.markets)),
          HubRow(id: "economy", title: "Economy", systemImage: "chart.bar", action: .push(.economy)),
          HubRow(id: "insights", title: "Insights", systemImage: "sparkles", isPro: true, action: .push(.insights)),
          HubRow(id: "reports", title: "Reports", systemImage: "chart.bar.doc.horizontal", action: .push(.reports)),
          HubRow(
            id: "chartBuilder", title: "Chart builder", systemImage: "chart.xyaxis.line", action: .push(.chartBuilder))
        ]),
      HubSection(id: "community", title: "Community", rows: community),
      HubSection(
        id: "account", title: "Account",
        rows: [
          HubRow(
            id: "brokers", title: "Brokers and imports", systemImage: "arrow.left.arrow.right", action: .push(.brokers)),
          HubRow(id: "settings", title: "Settings", systemImage: "gearshape", action: .push(.settings))
        ])
    ]
  }

  /// The name shown on the account row, and the avatar's initial, the same
  /// way Settings picks them: username, else email.
  static func account(username: String?, email: String?) -> HubAccount {
    let name = [username, email]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .first { !$0.isEmpty }
    return HubAccount(name: name, initial: name.map { String($0.prefix(1)).uppercased() } ?? "?")
  }
}

/// Plan (spec §7.11): Goals, Your future, Tax. Goal rows with progress and
/// the tax estimate come in P4.
nonisolated enum PlanHubModel {
  static func sections() -> [HubSection] {
    [
      HubSection(
        id: "goals", title: "Goals",
        rows: [HubRow(id: "goals", title: "Goals", systemImage: "flag", action: .push(.goals))]),
      HubSection(
        id: "yourFuture", title: "Your future",
        rows: [
          HubRow(
            id: "netWorthForecast", title: "Net worth forecast", systemImage: "chart.line.uptrend.xyaxis",
            isPro: true, action: .push(.netWorthForecast)),
          HubRow(id: "retirement", title: "Retirement", systemImage: "beach.umbrella", action: .push(.retirement)),
          HubRow(
            id: "scenarios", title: "Scenarios", systemImage: "arrow.triangle.branch", isPro: true,
            action: .push(.scenarios)),
          HubRow(id: "simulator", title: "Simulator", systemImage: "slider.horizontal.3", action: .push(.simulator)),
          HubRow(id: "grow", title: "Grow", systemImage: "leaf", action: .push(.grow)),
          HubRow(id: "tools", title: "Tools", systemImage: "wrench.and.screwdriver", action: .push(.tools))
        ]),
      HubSection(
        id: "tax", title: "Tax",
        rows: [
          HubRow(id: "taxStrategy", title: "Tax strategy", systemImage: "building.columns", action: .push(.tax)),
          HubRow(id: "terminalSizing", title: "Terminal sizing", systemImage: "scope", action: .push(.terminalSizing))
        ])
    ]
  }
}
