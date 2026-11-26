import Factory
import StockPlanShared
import SwiftUI

/// The More tab (spec §7.10): the account, then Intelligence, Community and
/// Account. Its stack is the one Social and Groups push their own routes onto,
/// hence a `NavigationPath`.
struct MoreHubScreen: View {
  @Binding var path: NavigationPath
  /// A row that leaves More, such as Market brief, which lives on Today.
  let onSelectTab: (AppTab, NavigationRequest) -> Void
  @InjectedObservable(\Container.billingManager) private var billingManager
  @InjectedObservable(\Container.socialStore) private var socialStore
  @InjectedObservable(\Container.groupsStore) private var groupsStore
  @State private var profile = UserProfileViewModel()
  @State private var isPaywallPresented = false
  @Environment(\.locale) private var locale

  var body: some View {
    NavigationStack(path: $path) {
      List {
        Section {
          accountRow
        }
        HubSectionsView(
          sections: MoreHubModel.sections(
            social: socialStore.config, groupsBadge: groupsStore.badgeCount, locale: locale),
          userIsPro: billingManager.isPro,
          onTap: handle
        )
      }
      .vigilListChrome()
      .navigationTitle(Text(AppTab.more.title))
      .navigationDestination(for: AppDestination.self) { destinationView($0) }
      // Forced, so a name changed in Settings shows on the way back.
      .task { await profile.load(force: true) }
      .sheet(isPresented: $isPaywallPresented) {
        PaywallView(billingManager: billingManager)
      }
    }
  }

  private var account: HubAccount {
    MoreHubModel.account(username: profile.profile?.username, email: profile.profile?.email)
  }

  private var accountRow: some View {
    Button {
      path.append(AppDestination.settings)
    } label: {
      HStack(spacing: AppTheme.Spacing.md) {
        Text(verbatim: account.initial)
          .font(.headline)
          .foregroundStyle(AppTheme.Colors.tint)
          .frame(width: 44, height: 44)
          .background(AppTheme.Colors.tintSoft, in: Circle())
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
          Group {
            if let name = account.name {
              Text(verbatim: name)
            } else {
              Text("Account")
            }
          }
          .font(.headline)
          .foregroundStyle(AppTheme.Colors.foreground)
          Group {
            if billingManager.isPro {
              Text("Pro")
            } else {
              Text("Free")
            }
          }
          .font(.subheadline)
          .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        Spacer(minLength: AppTheme.Spacing.sm)
        HubChevron()
      }
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .accessibilityHint(Text("Opens Settings"))
    .accessibilityIdentifier("hub.account")
  }

  private func handle(_ row: HubRow) {
    switch row.tap(userIsPro: billingManager.isPro) {
    case .paywall:
      isPaywallPresented = true
    case let .perform(.push(destination)):
      path.append(destination)
    case let .perform(.selectTab(tab, request)):
      onSelectTab(tab, request)
    }
  }
}

/// A hub's sections, inside its `List`.
struct HubSectionsView: View {
  let sections: [HubSection]
  let userIsPro: Bool
  let onTap: (HubRow) -> Void

  var body: some View {
    ForEach(sections) { section in
      Section {
        ForEach(section.rows) { row in
          HubRowButton(row: row, isLocked: row.tap(userIsPro: userIsPro) == .paywall) { onTap(row) }
        }
      } header: {
        Text(section.title)
      }
    }
  }
}

/// A hub row: symbol, title, optional value, Pro mark.
struct HubRowButton: View {
  let row: HubRow
  /// A Pro row the user can't open yet: the tap shows the paywall.
  let isLocked: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: AppTheme.Spacing.md) {
        Image(systemName: row.systemImage)
          .symbolRenderingMode(.monochrome)
          .foregroundStyle(AppTheme.Colors.secondaryText)
          .frame(width: 28)
          .accessibilityHidden(true)
        Text(row.title)
          .foregroundStyle(AppTheme.Colors.foreground)
        Spacer(minLength: AppTheme.Spacing.sm)
        if let value = row.value {
          Text(verbatim: value)
            .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        if row.isPro {
          ProBadge()
        }
        HubChevron()
      }
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .accessibilityHint(isLocked ? Text("Opens the Pro upgrade") : Text(verbatim: ""))
    .accessibilityIdentifier("hub.row.\(row.id)")
  }
}

/// The disclosure mark a `NavigationLink` row would draw. Hub rows are
/// buttons, because a Pro row may open the paywall instead of pushing.
private struct HubChevron: View {
  var body: some View {
    Image(systemName: "chevron.right")
      .font(.footnote.weight(.semibold))
      .foregroundStyle(AppTheme.Colors.tertiaryText)
      .accessibilityHidden(true)
  }
}
