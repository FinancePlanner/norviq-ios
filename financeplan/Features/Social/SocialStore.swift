import Factory
import Foundation
import Observation

/// The signed-in user's friend graph: friends, pending requests and people
/// they blocked. Shared by the Friends tab, its badge, search, profiles and
/// the invite sheet so a change made in one shows up everywhere.
@MainActor
@Observable
final class SocialStore {
  private(set) var config: SocialConfig = .disabled
  private(set) var friends: [SocialUserSummary] = []
  private(set) var incoming: [FriendRequest] = []
  private(set) var outgoing: [FriendRequest] = []
  private(set) var blocked: [SocialUserSummary] = []
  private(set) var isLoading = false
  private(set) var hasLoaded = false
  var errorMessage: String?

  private let service: any SocialServicing

  init(service: any SocialServicing = Container.shared.socialService()) {
    self.service = service
  }

  /// Friend requests waiting on the user. Messages add to this in Phase 4.
  var badgeCount: Int { incoming.count }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      async let friends = service.friends()
      async let requests = service.friendRequests()
      let (friendList, requestList) = try await (friends, requests)
      self.friends = friendList
      sortFriends()
      incoming = requestList.incoming
      outgoing = requestList.outgoing
      errorMessage = nil
      hasLoaded = true
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func loadConfig() async {
    // Unreachable config reads as "off": the tab explains itself instead of
    // showing half a feature.
    config = (try? await service.config()) ?? .disabled
  }

  func loadBlocked() async {
    do {
      blocked = try await service.blockedUsers()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// What the store knows about this person, which beats a stale search row.
  func status(of userID: String) -> FriendshipStatus {
    if friends.contains(where: { $0.id == userID }) { return .friends }
    if blocked.contains(where: { $0.id == userID }) { return .blocked }
    if incoming.contains(where: { $0.from.id == userID }) { return .incomingPending }
    if outgoing.contains(where: { $0.to.id == userID }) { return .outgoingPending }
    return .none
  }

  @discardableResult
  func sendRequest(to user: SocialUserSummary) async -> Bool {
    // They already asked us: accepting is what the user means.
    if let existing = incoming.first(where: { $0.from.id == user.id }) {
      return await respond(to: existing, accept: true)
    }
    do {
      let request = try await service.sendFriendRequest(userId: user.id)
      outgoing.removeAll { $0.id == request.id }
      outgoing.append(request)
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  @discardableResult
  func respond(to request: FriendRequest, accept: Bool) async -> Bool {
    do {
      try await service.respond(to: request.id, accept: accept)
      incoming.removeAll { $0.id == request.id }
      if accept {
        var friend = request.from
        friend.friendshipStatus = .friends
        friends.removeAll { $0.id == friend.id }
        friends.append(friend)
        sortFriends()
      }
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  private func sortFriends() {
    friends.sort { $0.sortName.localizedCaseInsensitiveCompare($1.sortName) == .orderedAscending }
  }

  func cancel(_ request: FriendRequest) async {
    do {
      try await service.cancelFriendRequest(requestId: request.id)
      outgoing.removeAll { $0.id == request.id }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func unfriend(_ user: SocialUserSummary) async {
    do {
      try await service.removeFriend(userId: user.id)
      friends.removeAll { $0.id == user.id }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Blocking also ends the friendship and drops pending requests both ways,
  /// matching what the server does.
  func block(_ user: SocialUserSummary) async {
    do {
      try await service.setBlocked(userId: user.id, blocked: true)
      friends.removeAll { $0.id == user.id }
      incoming.removeAll { $0.from.id == user.id }
      outgoing.removeAll { $0.to.id == user.id }
      var blockedUser = user
      blockedUser.friendshipStatus = .blocked
      blocked.removeAll { $0.id == user.id }
      blocked.append(blockedUser)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func unblock(_ user: SocialUserSummary) async {
    do {
      try await service.setBlocked(userId: user.id, blocked: false)
      blocked.removeAll { $0.id == user.id }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func report(userID: String, reason: ReportReason, note: String?) async -> Bool {
    let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
    do {
      try await service.report(
        ReportRequest(targetType: .user, targetId: userID, reason: reason, note: trimmed?.isEmpty == false ? trimmed : nil)
      )
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  func invitePreview(code: String) async throws -> SocialUserSummary {
    try await service.invitePreview(code: code)
  }

  /// Redeeming sends the inviter a request (or befriends them, server's call);
  /// the graph is reloaded either way.
  func redeemInvite(code: String) async -> Bool {
    do {
      _ = try await service.redeemInvite(code: code)
      await load()
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  /// Signing out must not leave one account's friends on screen for the next.
  func reset() {
    config = .disabled
    friends = []
    incoming = []
    outgoing = []
    blocked = []
    hasLoaded = false
    errorMessage = nil
  }
}
