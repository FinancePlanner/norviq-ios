import Factory
import StockPlanShared
import SwiftUI

/// One group, showing one channel's chat. The title is a menu of the
/// group's channels; ⓘ opens the group's info.
struct GroupScreen: View {
  @InjectedObservable(\Container.groupsStore) private var store
  @Environment(\.dismiss) private var dismiss
  let groupID: UUID
  let requestedChannelID: UUID?
  @State private var detail: GroupDetail?
  @State private var channelID: UUID?
  @State private var errorMessage: String?
  @State private var isInfoPresented = false
  @State private var isInvitePresented = false

  private let service: any GroupsServicing = Container.shared.groupsService()

  var body: some View {
    Group {
      if let detail, let channel = currentChannel(in: detail) {
        GroupChatView(detail: detail, channel: channel, onInvite: { isInvitePresented = true })
          .id(channel.id)
      } else if let errorMessage {
        ContentUnavailableView {
          Label("Can't open this group", systemImage: "bubble.left.and.exclamationmark.bubble.right")
        } description: {
          Text(errorMessage)
        } actions: {
          Button("Try again") { Task { await load() } }
        }
      } else {
        ProgressView()
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if let detail {
        ToolbarItem(placement: .principal) { channelMenu(detail) }
        ToolbarItem(placement: .primaryAction) {
          Button("Group info", systemImage: "info.circle") { isInfoPresented = true }
            .accessibilityIdentifier("groups.info")
        }
      }
    }
    .task { await load() }
    .onChange(of: store.detailRevision[groupID]) { _, _ in
      Task { await load() }
    }
    .onChange(of: store.removedGroupID) { _, removed in
      if removed == groupID { dismiss() }
    }
    .sheet(isPresented: $isInfoPresented) {
      if let detail {
        GroupInfoScreen(detail: detail, onChanged: { Task { await load() } }, onLeft: { dismiss() })
      }
    }
    .sheet(isPresented: $isInvitePresented) {
      if let detail { GroupInviteSheet(group: detail.group) }
    }
  }

  private func currentChannel(in detail: GroupDetail) -> GroupChannel? {
    let channels = detail.channels
    return channels.first { $0.id == channelID } ?? channels.first { $0.id == detail.group.defaultChannelId } ?? channels.first
  }

  private func channelMenu(_ detail: GroupDetail) -> some View {
    Menu {
      Section(detail.group.name) {
        ForEach(detail.channels.sorted { $0.position < $1.position }) { channel in
          Button {
            channelID = channel.id
          } label: {
            if channel.unreadCount > 0 {
              Label("#\(channel.name) · \(channel.unreadCount)", systemImage: "circle.fill")
            } else {
              Text("#\(channel.name)")
            }
          }
        }
      }
    } label: {
      VStack(spacing: 0) {
        HStack(spacing: 2) {
          Text("# \(currentChannel(in: detail)?.name ?? "")").font(.headline)
          Image(systemName: "chevron.down").font(.caption2.weight(.bold))
        }
        Text(detail.group.name).font(.caption2).foregroundStyle(.secondary)
      }
      .foregroundStyle(.primary)
    }
    .accessibilityIdentifier("groups.channelMenu")
  }

  private func load() async {
    do {
      let loaded = try await service.group(id: groupID)
      detail = loaded
      if channelID == nil || !loaded.channels.contains(where: { $0.id == channelID }) {
        let preferred = [requestedChannelID, store.lastViewedChannel(in: groupID), loaded.group.defaultChannelId]
        channelID = preferred.compactMap(\.self).first { id in loaded.channels.contains { $0.id == id } }
          ?? loaded.channels.first?.id
      }
      errorMessage = nil
    } catch {
      if detail == nil { errorMessage = error.localizedDescription }
    }
  }
}
