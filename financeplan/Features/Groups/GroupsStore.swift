import Factory
import Foundation
import Observation
import OSLog
import StockPlanShared

/// The signed-in user's groups, invitations and the live connection. Shared
/// by the Groups tab, its badge, every chat screen and push handling, so a
/// message read in one place clears its unread everywhere.
@MainActor
@Observable
final class GroupsStore {
  enum ConnectionState: Equatable {
    case idle
    case connecting
    case live
    /// Waiting to reconnect after the stream dropped.
    case offline
  }

  private(set) var groups: [GroupSummary] = []
  private(set) var invitations: [GroupInvitation] = []
  private(set) var pendingInvitationCount = 0
  private(set) var isLoading = false
  private(set) var hasLoaded = false
  private(set) var connection: ConnectionState = .idle
  /// The signed-in user, to tell their own messages apart.
  private(set) var currentUserID: UUID?
  var errorMessage: String?

  /// A link or push that asked to open something; `GroupsRoot` consumes it.
  var pendingLink: GroupDeepLink?
  /// Bumped when a group's channels or settings change, so an open group
  /// screen reloads its detail.
  private(set) var detailRevision: [UUID: Int] = [:]
  /// The group the user was just removed from; open screens for it close.
  private(set) var removedGroupID: UUID?

  /// The channel on screen, which gets live messages and suppresses its
  /// own push banners.
  private(set) var activeChat: GroupChatModel?
  private var activeChatToken: UUID?

  private let service: any GroupsServicing
  private let defaults: UserDefaults
  private var realtimeTask: Task<Void, Never>?
  private var refreshTask: Task<Void, Never>?
  private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "financeplan", category: "GroupsStore")
  private static let lastChannelKey = "groups.lastViewedChannel"

  init(service: any GroupsServicing = Container.shared.groupsService(), defaults: UserDefaults = .standard) {
    self.service = service
    self.defaults = defaults
  }

  /// Unread messages across the user's groups.
  var unreadCount: Int {
    groups.reduce(0) { $0 + ($1.membership == nil ? 0 : $1.unreadCount) }
  }

  /// What the Groups tab badge shows, before friend requests are added.
  var badgeCount: Int { unreadCount + pendingInvitationCount }

  // MARK: Loading

  func load() async {
    if currentUserID == nil { currentUserID = await service.currentUserID() }
    isLoading = true
    defer { isLoading = false }
    do {
      let response = try await service.myGroups()
      groups = response.items
      pendingInvitationCount = response.pendingInvitationCount
      if pendingInvitationCount > 0 || !invitations.isEmpty {
        invitations = (try? await service.invitations().items) ?? invitations
      }
      hasLoaded = true
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Coalesces bursts of list-changing events into one reload.
  func refreshSoon() {
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(400))
      guard !Task.isCancelled else { return }
      await self?.load()
    }
  }

  func summary(for groupID: UUID) -> GroupSummary? {
    groups.first { $0.id == groupID }
  }

  // MARK: Last viewed channel

  /// Where tapping a group lands: the channel last open in it, else #general.
  func lastViewedChannel(in groupID: UUID) -> UUID? {
    guard let stored = defaults.dictionary(forKey: Self.lastChannelKey) as? [String: String] else { return nil }
    return stored[groupID.uuidString].flatMap(UUID.init(uuidString:))
  }

  func rememberChannel(_ channelID: UUID, in groupID: UUID) {
    var stored = defaults.dictionary(forKey: Self.lastChannelKey) as? [String: String] ?? [:]
    stored[groupID.uuidString] = channelID.uuidString
    defaults.set(stored, forKey: Self.lastChannelKey)
  }

  // MARK: Chat presence

  /// Called by the chat screen as it appears. The token keeps a late
  /// disappear from clearing a newer screen.
  func chatDidAppear(_ chat: GroupChatModel) -> UUID {
    let token = UUID()
    activeChat = chat
    activeChatToken = token
    rememberChannel(chat.channelID, in: chat.groupID)
    chat.onRead = { [weak self] channelID, _ in
      self?.clearUnread(groupID: chat.groupID, channelID: channelID)
    }
    return token
  }

  func chatDidDisappear(token: UUID) {
    guard activeChatToken == token else { return }
    activeChat?.stop()
    activeChat = nil
    activeChatToken = nil
  }

  /// True while that channel is on screen; its pushes then show no banner.
  func isViewing(channelID: UUID) -> Bool {
    activeChat?.channelID == channelID
  }

  private func clearUnread(groupID: UUID, channelID _: UUID) {
    // The summary's count covers every channel; the server's is the truth.
    refreshSoon()
  }

  // MARK: Actions

  func create(_ request: CreateGroupRequest) async throws -> GroupDetail {
    let detail = try await service.create(request)
    upsert(detail.group)
    return detail
  }

  func join(_ groupID: UUID) async throws -> GroupDetail {
    let detail = try await service.join(groupId: groupID)
    upsert(detail.group)
    return detail
  }

  func redeem(code: String) async throws -> GroupDetail {
    let detail = try await service.redeemInvite(code: code)
    upsert(detail.group)
    return detail
  }

  func accept(_ invitation: GroupInvitation) async throws -> GroupDetail {
    let detail = try await service.acceptInvitation(id: invitation.id)
    removeInvitation(invitation.id)
    upsert(detail.group)
    return detail
  }

  func decline(_ invitation: GroupInvitation) async {
    do {
      try await service.declineInvitation(id: invitation.id)
      removeInvitation(invitation.id)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func leave(_ groupID: UUID) async throws {
    try await service.leave(groupId: groupID)
    groups.removeAll { $0.id == groupID }
  }

  func delete(_ groupID: UUID) async throws {
    try await service.delete(groupId: groupID)
    groups.removeAll { $0.id == groupID }
  }

  func setPushEnabled(_ enabled: Bool, for groupID: UUID) async throws {
    _ = try await service.setPushEnabled(groupId: groupID, enabled)
    refreshSoon()
  }

  private func upsert(_ summary: GroupSummary) {
    if let index = groups.firstIndex(where: { $0.id == summary.id }) {
      groups[index] = summary
    } else {
      groups.insert(summary, at: 0)
    }
  }

  private func removeInvitation(_ id: UUID) {
    invitations.removeAll { $0.id == id }
    pendingInvitationCount = max(0, pendingInvitationCount - 1)
  }

  // MARK: Live connection

  /// Opens the live stream and keeps it open, reconnecting with backoff,
  /// until `stopRealtime`. Call while the scene is active; pushes cover the
  /// background.
  func startRealtime() {
    guard realtimeTask == nil else { return }
    realtimeTask = Task { [weak self] in
      await self?.runRealtime()
    }
  }

  func stopRealtime() {
    realtimeTask?.cancel()
    realtimeTask = nil
    connection = .idle
  }

  private func runRealtime() async {
    var failures = 0
    var serverRetry: Duration = .seconds(2)
    while !Task.isCancelled {
      connection = .connecting
      do {
        for try await signal in service.realtime() {
          switch signal {
          case let .event(event):
            failures = 0
            await handle(event)
          case let .retry(milliseconds):
            serverRetry = .milliseconds(max(500, milliseconds))
          }
        }
      } catch let failure as GroupsRealtimeClient.Failure where !failure.isRetryable {
        Self.logger.info("groups.realtime stopped reason=\(String(describing: failure), privacy: .public)")
        connection = .idle
        realtimeTask = nil
        return
      } catch {
        failures += 1
      }
      guard !Task.isCancelled else { break }
      connection = .offline
      try? await Task.sleep(for: Self.backoff(failures: failures, serverRetry: serverRetry))
    }
  }

  /// The server's `retry` after a clean close; doubling up to 30s, with
  /// jitter, after failures, so a deploy doesn't bring every client back at once.
  nonisolated static func backoff(failures: Int, serverRetry: Duration) -> Duration {
    guard failures > 0 else { return serverRetry }
    let seconds = min(30.0, 2.0 * pow(2.0, Double(min(failures - 1, 5))))
    return .milliseconds(Int(seconds * 1000 * Double.random(in: 0.8...1.2)))
  }

  func handle(_ event: GroupRealtimeEvent) async {
    switch event.type {
    case .ready:
      connection = .live
      // No replay: whatever happened while disconnected comes over REST.
      await load()
      await activeChat?.catchUp()
    case .messageCreated:
      guard let message = event.message else { return }
      activeChat?.apply(event)
      noteMessage(message)
      if isViewing(channelID: message.channelId) { activeChat?.scheduleMarkRead() }
    case .messageDeleted:
      activeChat?.apply(event)
    case .channelRead:
      activeChat?.apply(event)
      refreshSoon()
    case .channelCreated, .channelUpdated, .channelDeleted, .groupUpdated:
      activeChat?.apply(event)
      if let groupID = event.groupId ?? event.group?.id ?? event.channel?.groupId {
        detailRevision[groupID, default: 0] += 1
      }
      refreshSoon()
    case .membershipRemoved:
      guard let groupID = event.groupId else { return }
      groups.removeAll { $0.id == groupID }
      removedGroupID = groupID
    case .invitationReceived:
      if let invitation = event.invitation, !invitations.contains(where: { $0.id == invitation.id }) {
        invitations.insert(invitation, at: 0)
        pendingInvitationCount += 1
      } else {
        refreshSoon()
      }
    case .reconnect, .other:
      break
    }
  }

  /// Moves the group to the top with the new preview, and counts it unread
  /// unless it's the user's own or on screen.
  private func noteMessage(_ message: GroupMessage) {
    guard let index = groups.firstIndex(where: { $0.id == message.groupId }) else {
      refreshSoon()
      return
    }
    let current = groups[index]
    let isOwn = message.authorId != nil && message.authorId == currentUserID
    let counts = !isOwn && !isViewing(channelID: message.channelId)
    let updated = GroupSummary(
      id: current.id,
      name: current.name,
      description: current.description,
      iconEmoji: current.iconEmoji,
      topic: current.topic,
      ticker: current.ticker,
      visibility: current.visibility,
      memberCount: current.memberCount,
      defaultChannelId: current.defaultChannelId,
      lastMessageAt: message.createdAt,
      lastMessage: GroupMessagePreview(
        authorUsername: message.authorUsername,
        excerpt: message.body.map { String($0.prefix(140)) },
        createdAt: message.createdAt
      ),
      unreadCount: current.unreadCount + (counts ? 1 : 0),
      membership: current.membership,
      createdAt: current.createdAt
    )
    groups.remove(at: index)
    groups.insert(updated, at: 0)
  }

  /// Signing out must not leave one account's groups on screen for the next.
  func reset() {
    stopRealtime()
    refreshTask?.cancel()
    groups = []
    invitations = []
    pendingInvitationCount = 0
    hasLoaded = false
    pendingLink = nil
    detailRevision = [:]
    removedGroupID = nil
    activeChat = nil
    activeChatToken = nil
    currentUserID = nil
    errorMessage = nil
  }
}
