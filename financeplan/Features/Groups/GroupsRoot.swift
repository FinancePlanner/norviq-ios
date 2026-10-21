import Factory
import StockPlanShared
import SwiftUI

/// Where the Groups tab navigates.
enum GroupsRoute: Hashable {
  /// A group, opened on `channelID` or else its last-viewed channel.
  case group(UUID, channelID: UUID?)
  case discover
}

/// The Groups tab: invitations, the user's groups, and ways to start or
/// find one. A NavigationStack on iPhone and iPad alike; the iPad split view
/// (groups, channels, chat) comes later.
struct GroupsRoot: View {
  @InjectedObservable(\Container.groupsStore) private var store
  @InjectedObservable(\Container.socialStore) private var socialStore
  @InjectedObservable(\Container.boardsViewerStore) private var viewer
  @State private var path: [GroupsRoute] = []
  @State private var isCreating = false
  @State private var joinCode: GroupJoinRequest?

  var body: some View {
    NavigationStack(path: $path) {
      Group {
        if viewer.isBanned {
          ContentUnavailableView(
            "Groups unavailable",
            systemImage: "hand.raised",
            description: Text("Your access to the Norviq community has been removed. The rest of Norviq works as usual.")
          )
        } else {
          GroupsHomeScreen(
            onOpen: { path.append(.group($0, channelID: nil)) },
            onCreate: { isCreating = true },
            onJoinWithLink: { joinCode = GroupJoinRequest(code: nil) },
            onDiscover: { path.append(.discover) }
          )
        }
      }
      .navigationDestination(for: GroupsRoute.self) { route in
        switch route {
        case let .group(groupID, channelID):
          GroupScreen(groupID: groupID, requestedChannelID: channelID)
        case .discover:
          GroupDiscoverScreen { path.append(.group($0, channelID: nil)) }
        }
      }
    }
    .task {
      await viewer.load()
      if !store.hasLoaded { await store.load() }
      consumePendingLink()
    }
    .onChange(of: store.pendingLink) { _, _ in consumePendingLink() }
    .sheet(isPresented: $isCreating) {
      CreateGroupSheet { detail in
        path = [.group(detail.group.id, channelID: detail.group.defaultChannelId)]
      }
    }
    .sheet(item: $joinCode) { request in
      GroupJoinSheet(initialCode: request.code) { detail in
        path = [.group(detail.group.id, channelID: nil)]
      }
    }
  }

  private func consumePendingLink() {
    guard let link = store.pendingLink else { return }
    store.pendingLink = nil
    switch link {
    case let .channel(groupID, channelID):
      path = [.group(groupID, channelID: channelID)]
    case let .group(groupID):
      path = [.group(groupID, channelID: nil)]
    case .invitations:
      path = []
      Task { await store.load() }
    case let .invite(code):
      path = []
      joinCode = GroupJoinRequest(code: code)
    }
  }
}

struct GroupJoinRequest: Identifiable {
  let id = UUID()
  let code: String?
}

/// The list itself: invitations, then the user's groups, then discovery.
struct GroupsHomeScreen: View {
  @InjectedObservable(\Container.groupsStore) private var store
  @InjectedObservable(\Container.socialStore) private var socialStore
  @InjectedObservable(\Container.boardsViewerStore) private var viewer
  let onOpen: (UUID) -> Void
  let onCreate: () -> Void
  let onJoinWithLink: () -> Void
  let onDiscover: () -> Void

  var body: some View {
    List {
      BoardsViewerBanner()
      if !socialStore.incoming.isEmpty {
        Section {
          Button {
            NotificationCenter.default.post(name: .openSocialFromPushNotification, object: nil)
          } label: {
            Label(
              "^[\(socialStore.incoming.count) friend request](inflect: true) waiting",
              systemImage: "person.badge.plus"
            )
          }
          .accessibilityIdentifier("groups.friendRequests")
        }
      }
      if !store.invitations.isEmpty {
        Section("Invitations") {
          ForEach(store.invitations) { invitation in
            GroupInvitationRow(invitation: invitation, onJoined: onOpen)
          }
        }
      }
      if store.groups.isEmpty, store.hasLoaded {
        emptyState
      } else {
        Section("Your groups") {
          ForEach(store.groups) { group in
            Button {
              onOpen(group.id)
            } label: {
              GroupSummaryRow(group: group)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("groups.group.\(group.id.uuidString)")
          }
        }
      }
      if socialStore.config.groupsPublic {
        Section {
          Button("Discover public groups", systemImage: "magnifyingglass", action: onDiscover)
            .accessibilityIdentifier("groups.discover")
        }
      }
    }
    .navigationTitle("Groups")
    .overlay {
      if !store.hasLoaded, store.isLoading { ProgressView() }
    }
    .refreshable {
      await store.load()
      await socialStore.load()
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Menu {
          Button("New group", systemImage: "plus.bubble", action: onCreate)
            .disabled(!viewer.canWrite && !viewer.needsGuidelines)
          Button("Join with a link", systemImage: "link", action: onJoinWithLink)
        } label: {
          Label("New", systemImage: "plus")
        }
        .accessibilityIdentifier("groups.add")
      }
    }
    .alert("Something went wrong", isPresented: errorAlertBinding(Binding(get: { store.errorMessage }, set: { store.errorMessage = $0 }))) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(store.errorMessage ?? "")
    }
  }

  private var emptyState: some View {
    Section {
      VStack(spacing: 12) {
        Image(systemName: "bubble.left.and.bubble.right.fill")
          .font(.largeTitle)
          .foregroundStyle(AppTheme.Colors.tint)
        Text("Chat about what you hold, with people you trust")
          .font(.headline)
          .multilineTextAlignment(.center)
        Text("Start a group for a stock, an ETF or anything else, then invite friends. Each group gets a #general channel to begin with.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Button("Create a group", action: onCreate)
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("groups.empty.create")
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
    }
  }
}

/// A group in a list: emoji tile, name, ticker, last message and unread count.
struct GroupSummaryRow: View {
  let group: GroupSummary

  var body: some View {
    HStack(spacing: 12) {
      GroupIcon(emoji: group.iconEmoji, name: group.name)
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(group.name).font(.headline).lineLimit(1)
          if let ticker = group.ticker {
            Text("$\(ticker)")
              .font(.caption.weight(.semibold))
              .padding(.horizontal, 6)
              .padding(.vertical, 1)
              .background(AppTheme.Colors.tint.opacity(0.15), in: Capsule())
              .foregroundStyle(AppTheme.Colors.tint)
          }
          if group.visibility == .private {
            Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
              .accessibilityLabel("Private")
          }
          if group.membership?.pushEnabled == false {
            Image(systemName: "bell.slash.fill").font(.caption2).foregroundStyle(.secondary)
              .accessibilityLabel("Muted")
          }
        }
        Text(previewText)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 4) {
        if let at = group.lastMessageAt {
          Text(BoardAge.short(at)).font(.caption).foregroundStyle(.secondary)
        }
        if group.unreadCount > 0 {
          Text(group.unreadCount > 99 ? "99+" : "\(group.unreadCount)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(AppTheme.Colors.tint, in: Capsule())
            .foregroundStyle(.white)
            .accessibilityLabel("^[\(group.unreadCount) unread message](inflect: true)")
        }
      }
    }
    .padding(.vertical, 2)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
  }

  private var previewText: String {
    guard let last = group.lastMessage else {
      return group.membership == nil
        ? String(localized: "^[\(group.memberCount) member](inflect: true)")
        : String(localized: "No messages yet")
    }
    let excerpt = last.excerpt ?? String(localized: "Message deleted")
    return last.authorUsername.map { "\($0): \(excerpt)" } ?? excerpt
  }
}

/// The group's emoji on a tinted tile, or its initial.
struct GroupIcon: View {
  let emoji: String?
  let name: String
  var size: CGFloat = 44

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: size * 0.3)
        .fill(AppTheme.Colors.tint.opacity(0.15))
      if let emoji, !emoji.isEmpty {
        Text(emoji).font(.system(size: size * 0.5))
      } else {
        Text(String(name.prefix(1)).uppercased())
          .font(.system(size: size * 0.42, weight: .semibold))
          .foregroundStyle(AppTheme.Colors.tint)
      }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

private struct GroupInvitationRow: View {
  @InjectedObservable(\Container.groupsStore) private var store
  let invitation: GroupInvitation
  let onJoined: (UUID) -> Void
  @State private var isWorking = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 12) {
        GroupIcon(emoji: invitation.group.iconEmoji, name: invitation.group.name, size: 36)
        VStack(alignment: .leading, spacing: 2) {
          Text(invitation.group.name).font(.headline)
          if let inviter = invitation.inviterUsername {
            Text("@\(inviter) invited you").font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      HStack {
        Button("Join") {
          Task {
            isWorking = true
            defer { isWorking = false }
            do {
              let detail = try await store.accept(invitation)
              onJoined(detail.group.id)
            } catch {
              store.errorMessage = error.localizedDescription
            }
          }
        }
        .buttonStyle(.borderedProminent)
        Button("Decline") {
          Task { await store.decline(invitation) }
        }
        .buttonStyle(.bordered)
      }
      .disabled(isWorking)
      .controlSize(.small)
    }
    .padding(.vertical, 4)
  }
}
