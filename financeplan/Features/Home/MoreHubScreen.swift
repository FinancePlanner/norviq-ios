import Factory
import StockPlanShared
import SwiftUI

/// The More tab (spec §7.10): the account, then Intelligence, Community and
/// Account. Its stack is the one Social and Groups push their own routes onto,
/// hence a `NavigationPath`.
struct MoreHubScreen: View {
  @Binding var path: NavigationPath
  /// An invite link that opened the app, for Friends once it is pushed.
  @Binding var pendingInviteCode: String?
  /// A Friends section a push asked for (`feed`), consumed by Friends.
  @Binding var pendingSocialSection: String?
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
            social: socialStore.config, groupsBadge: groupsStore.badgeCount,
            friendsBadge: socialStore.badgeCount, locale: locale),
          userIsPro: billingManager.isPro,
          onTap: handle
        )
      }
      .vigilListChrome()
      .navigationTitle(Text(AppTab.more.title))
      .navigationDestination(for: AppDestination.self) {
        destinationView(
          $0, path: $path, pendingInviteCode: $pendingInviteCode, pendingSocialSection: $pendingSocialSection)
      }
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
        AccountAvatar(initial: account.initial, size: 44)
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

/// The signed-in user's initial in a circle: More's account row, and the
/// button on Today that opens Settings.
struct AccountAvatar: View {
  let initial: String
  let size: CGFloat

  var body: some View {
    Text(verbatim: initial)
      .font(size < 44 ? .subheadline.weight(.semibold) : .headline)
      .foregroundStyle(AppTheme.Colors.tint)
      .frame(width: size, height: size)
      .background(AppTheme.Colors.tintSoft, in: Circle())
      .accessibilityHidden(true)
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
