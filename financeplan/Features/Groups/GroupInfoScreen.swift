import Factory
import StockPlanShared
import SwiftUI

/// A group's settings: notifications, invites, channels, members, and
/// leaving or deleting it.
struct GroupInfoScreen: View {
  @InjectedObservable(\Container.groupsStore) private var store
  @Environment(\.dismiss) private var dismiss
  let detail: GroupDetail
  let onChanged: () -> Void
  let onLeft: () -> Void
  @State private var pushEnabled: Bool
  @State private var members: [GroupMember] = []
  @State private var membersCursor: String?
  @State private var isInvitePresented = false
  @State private var isAddingChannel = false
  @State private var newChannelName = ""
  @State private var confirmLeave = false
  @State private var confirmDelete = false
  @State private var errorMessage: String?

  private let service: any GroupsServicing = Container.shared.groupsService()

  init(detail: GroupDetail, onChanged: @escaping () -> Void, onLeft: @escaping () -> Void) {
    self.detail = detail
    self.onChanged = onChanged
    self.onLeft = onLeft
    _pushEnabled = State(initialValue: detail.group.membership?.pushEnabled ?? false)
  }

  private var group: GroupSummary { detail.group }
  private var permissions: GroupPermissions { detail.permissions }
  private var isOwner: Bool { group.membership?.role == .owner }

  var body: some View {
    NavigationStack {
      List {
        header
        if group.membership != nil {
          Section {
            Toggle("Notifications", isOn: Binding(get: { pushEnabled }, set: { setPush($0) }))
            if permissions.canInvite {
              Button("Invite friends", systemImage: "person.badge.plus") { isInvitePresented = true }
            }
          }
        }
        channelsSection
        membersSection
        Section {
          if group.membership != nil, !isOwner {
            Button("Leave group", role: .destructive) { confirmLeave = true }
          }
          if permissions.canDelete {
            Button("Delete group", role: .destructive) { confirmDelete = true }
          }
        } footer: {
          if isOwner {
            Text("To leave a group you own, make someone else the owner first, or delete it.")
          }
        }
      }
      .navigationTitle("Group info")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
      .task { await loadMembers(reset: true) }
      .sheet(isPresented: $isInvitePresented) { GroupInviteSheet(group: group) }
      .alert("New channel", isPresented: $isAddingChannel) {
        TextField("channel-name", text: $newChannelName)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
        Button("Create") { Task { await addChannel() } }
        Button("Cancel", role: .cancel) { newChannelName = "" }
      } message: {
        Text("Lowercase letters, numbers and dashes.")
      }
      .confirmationDialog("Leave \(group.name)?", isPresented: $confirmLeave, titleVisibility: .visible) {
        Button("Leave", role: .destructive) { Task { await leave() } }
      }
      .confirmationDialog("Delete \(group.name) for everyone?", isPresented: $confirmDelete, titleVisibility: .visible) {
        Button("Delete group", role: .destructive) { Task { await deleteGroup() } }
      } message: {
        Text("All channels and messages go with it. This can't be undone.")
      }
      .alert("Something went wrong", isPresented: errorAlertBinding($errorMessage)) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorMessage ?? "")
      }
    }
  }

  private var header: some View {
    Section {
      HStack(spacing: 12) {
        GroupIcon(emoji: group.iconEmoji, name: group.name, size: 56)
        VStack(alignment: .leading, spacing: 4) {
          Text(group.name).font(.title3.weight(.semibold))
          HStack(spacing: 6) {
            if let ticker = group.ticker { Text("$\(ticker)").foregroundStyle(AppTheme.Colors.tint) }
            Text(group.visibility == .private ? "Invite only" : "Public")
            Text(verbatim: "·")
            Text("^[\(group.memberCount) member](inflect: true)")
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
      if !group.description.isEmpty {
        Text(group.description).font(.subheadline)
      }
      if let owner = detail.ownerUsername {
        Text("Created by @\(owner)").font(.caption).foregroundStyle(.secondary)
      }
    }
  }

  private var channelsSection: some View {
    Section("Channels") {
      ForEach(detail.channels.sorted { $0.position < $1.position }) { channel in
        VStack(alignment: .leading, spacing: 2) {
          Text("#\(channel.name)")
          if let topic = channel.topic, !topic.isEmpty {
            Text(topic).font(.caption).foregroundStyle(.secondary)
          }
        }
        .swipeActions {
          if permissions.canManageChannels, detail.channels.count > 1 {
            Button("Delete", role: .destructive) { Task { await deleteChannel(channel) } }
          }
        }
      }
      if permissions.canManageChannels {
        Button("Add channel", systemImage: "plus") { isAddingChannel = true }
      }
    }
  }

  private var membersSection: some View {
    Section("Members") {
      ForEach(members) { member in
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text(member.displayName ?? member.username.map { "@\($0)" } ?? String(localized: "Member"))
            if let username = member.username, member.displayName != nil {
              Text("@\(username)").font(.caption).foregroundStyle(.secondary)
            }
          }
          Spacer()
          if member.role == .owner || member.role == .admin {
            Text(member.role == .owner ? "Owner" : "Admin").font(.caption).foregroundStyle(.secondary)
          }
        }
        .swipeActions {
          if permissions.canModerate, member.role != .owner, member.userId != store.currentUserID {
            Button("Ban", role: .destructive) { Task { await moderate(member, ban: true) } }
            Button("Remove") { Task { await moderate(member, ban: false) } }
              .tint(.orange)
          }
        }
        .contextMenu {
          if isOwner, member.role != .owner {
            Button(member.role == .admin ? "Make member" : "Make admin") {
              Task { await setRole(member, member.role == .admin ? .member : .admin) }
            }
            Button("Make owner") { Task { await transfer(to: member) } }
          }
        }
        .task {
          if member.id == members.last?.id { await loadMembers(reset: false) }
        }
      }
    }
  }

  // MARK: Actions

  private func setPush(_ enabled: Bool) {
    pushEnabled = enabled
    Task {
      do {
        try await store.setPushEnabled(enabled, for: group.id)
      } catch {
        pushEnabled = !enabled
        errorMessage = error.localizedDescription
      }
    }
  }

  private func loadMembers(reset: Bool) async {
    if !reset, membersCursor == nil { return }
    do {
      let page = try await service.members(groupId: group.id, cursor: reset ? nil : membersCursor)
      members = reset ? page.items : members + page.items.filter { item in !members.contains { $0.id == item.id } }
      membersCursor = page.nextCursor
    } catch {
      if reset { errorMessage = error.localizedDescription }
    }
  }

  private func addChannel() async {
    let name = newChannelName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      .replacingOccurrences(of: " ", with: "-")
    newChannelName = ""
    guard !name.isEmpty else { return }
    await perform { _ = try await service.createChannel(groupId: group.id, CreateGroupChannelRequest(name: name, topic: nil)) }
  }

  private func deleteChannel(_ channel: GroupChannel) async {
    await perform { try await service.deleteChannel(id: channel.id) }
  }

  private func moderate(_ member: GroupMember, ban: Bool) async {
    await perform {
      if ban {
        try await service.ban(groupId: group.id, userId: member.userId)
      } else {
        try await service.kick(groupId: group.id, userId: member.userId)
      }
      members.removeAll { $0.id == member.id }
    }
  }

  private func setRole(_ member: GroupMember, _ role: GroupRole) async {
    await perform {
      try await service.setRole(groupId: group.id, userId: member.userId, role: role)
      await loadMembers(reset: true)
    }
  }

  private func transfer(to member: GroupMember) async {
    await perform {
      try await service.transferOwnership(groupId: group.id, to: member.userId)
      await loadMembers(reset: true)
    }
  }

  private func leave() async {
    do {
      try await store.leave(group.id)
      dismiss()
      onLeft()
    } catch {
      errorMessage = (error as? GroupsHTTPClient.Error)?.code == "owner_must_transfer"
        ? String(localized: "Make someone else the owner before you leave.")
        : error.localizedDescription
    }
  }

  private func deleteGroup() async {
    do {
      try await store.delete(group.id)
      dismiss()
      onLeft()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func perform(_ action: () async throws -> Void) async {
    do {
      try await action()
      onChanged()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
