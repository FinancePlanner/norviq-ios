import Factory
import Foundation
import Observation
import StockPlanShared

/// The viewer's standing on Boards. Everything here is advisory: the server
/// refuses anything it doesn't allow, this only decides which controls to show.
@MainActor
@Observable
final class BoardsViewerStore {
  private(set) var status: CommunityViewerStatus?
  /// Unread Boards activity, for the bell badge.
  private(set) var unreadCount = 0
  /// A post a push or link asked to open; `BoardsRoot` presents it.
  var pendingPost: BoardsPendingPost?
  var errorMessage: String?

  private let service: any BoardsServicing

  init(service: any BoardsServicing = Container.shared.boardsService()) {
    self.service = service
  }

  var isAdmin: Bool { status?.isAdmin == true }
  var username: String? { status?.username }
  var isBanned: Bool { !isAdmin && status?.activeSanction?.kind == .ban }
  var isMuted: Bool { !isAdmin && status?.activeSanction?.kind == .mute }
  var needsUsername: Bool { status?.hasUsername == false }
  var needsGuidelines: Bool { status.map { !$0.guidelinesAccepted && !$0.isAdmin } ?? false }
  var canWrite: Bool { status != nil && !isBanned && !isMuted && !needsUsername && !needsGuidelines }
  var mutedUntil: Date? { isMuted ? status?.activeSanction?.expiresAt : nil }

  func load() async {
    do {
      status = try await service.viewer()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func refreshUnreadCount() async {
    if let count = try? await service.unreadCount() { unreadCount = count }
  }

  func clearUnread() {
    unreadCount = 0
  }

  func open(postID: UUID) {
    pendingPost = BoardsPendingPost(id: postID)
  }

  func acceptGuidelines() async {
    do {
      try await service.acceptGuidelines()
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

@MainActor
@Observable
final class BoardsDirectoryModel {
  private(set) var boards: [BoardSummary] = []
  private(set) var nextCursor: String?
  private(set) var isLoading = false
  var errorMessage: String?

  private let service: any BoardsServicing

  init(service: any BoardsServicing = Container.shared.boardsService()) {
    self.service = service
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      let page = try await service.boards(cursor: nil)
      boards = page.items
      nextCursor = page.nextCursor
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func loadMore() async {
    guard let cursor = nextCursor, !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    if let page = try? await service.boards(cursor: cursor) {
      boards.append(contentsOf: page.items)
      nextCursor = page.nextCursor
    }
  }

  /// Returns the new board, or nil with `errorMessage` set to the server's reason.
  func create(slug: String, name: String, description: String) async -> BoardSummary? {
    do {
      let board = try await service.createBoard(CreateBoardRequest(slug: slug, name: name, description: description))
      boards.insert(board, at: 0)
      errorMessage = nil
      return board
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }
}

@MainActor
@Observable
final class BoardFeedModel {
  let board: BoardSummary
  var sort: BoardPostSort = .new
  var kind: BoardPostKind?
  var tag: String?
  private(set) var posts: [BoardPostSummary] = []
  private(set) var nextCursor: String?
  private(set) var isLoading = false
  var errorMessage: String?

  private let service: any BoardsServicing

  init(board: BoardSummary, service: any BoardsServicing = Container.shared.boardsService()) {
    self.board = board
    self.service = service
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      let page = try await service.posts(slug: board.slug, sort: sort, kind: kind, tag: tag, cursor: nil)
      posts = page.items
      nextCursor = page.nextCursor
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func loadMore() async {
    guard let cursor = nextCursor, !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    if let page = try? await service.posts(slug: board.slug, sort: sort, kind: kind, tag: tag, cursor: cursor) {
      posts.append(contentsOf: page.items)
      nextCursor = page.nextCursor
    }
  }

  func toggleKind(_ value: BoardPostKind) async {
    kind = kind == value ? nil : value
    await load()
  }

  func vote(_ post: BoardPostSummary) async {
    do {
      let result = try await service.vote(postId: post.id)
      replace(post.id) { $0.applying(result) }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func delete(_ post: BoardPostSummary) async {
    do {
      try await service.deletePost(id: post.id)
      posts.removeAll { $0.id == post.id }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Drops posts by someone the viewer just blocked; the server hides them
  /// from the next load anyway.
  func hidePosts(by username: String) {
    posts.removeAll { $0.authorUsername == username }
  }

  func prepend(_ post: BoardPostSummary) {
    posts.insert(post, at: 0)
  }

  private func replace(_ id: UUID, with transform: (BoardPostSummary) -> BoardPostSummary) {
    guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
    posts[index] = transform(posts[index])
  }
}

@MainActor
@Observable
final class BoardPostDetailModel {
  let postId: UUID
  private(set) var detail: BoardPostDetail?
  private(set) var thread: [BoardThreadRow] = []
  private(set) var isLoading = false
  var errorMessage: String?

  private let service: any BoardsServicing

  init(postId: UUID, service: any BoardsServicing = Container.shared.boardsService()) {
    self.postId = postId
    self.service = service
  }

  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      let detail = try await service.post(id: postId)
      self.detail = detail
      thread = BoardThread.rows(for: detail.comments)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func vote() async {
    guard let detail else { return }
    do {
      let result = try await service.vote(postId: postId)
      self.detail = BoardPostDetail(post: detail.post.applying(result), body: detail.body, comments: detail.comments)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// True when the comment was posted.
  func comment(_ body: String, parentId: UUID?) async -> Bool {
    do {
      _ = try await service.comment(postId: postId, CreateBoardCommentRequest(parentId: parentId, body: body))
      await load()
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  func deleteComment(_ id: UUID) async {
    do {
      try await service.deleteComment(id: id)
      await load()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

/// A comment placed in its thread: replies follow their parent, depth-first.
struct BoardThreadRow: Identifiable, Equatable {
  let comment: BoardComment
  let depth: Int
  var id: UUID { comment.id }
}

enum BoardThread {
  static let maxDepth = 8

  /// Orders a flat comment list depth-first. A reply whose parent is missing
  /// is shown at the top level rather than lost.
  static func rows(for comments: [BoardComment]) -> [BoardThreadRow] {
    let known = Set(comments.map(\.id))
    var children: [UUID: [BoardComment]] = [:]
    var roots: [BoardComment] = []
    for comment in comments {
      if let parent = comment.parentId, known.contains(parent) {
        children[parent, default: []].append(comment)
      } else {
        roots.append(comment)
      }
    }
    var rows: [BoardThreadRow] = []
    rows.reserveCapacity(comments.count)
    func walk(_ comment: BoardComment, depth: Int) {
      rows.append(BoardThreadRow(comment: comment, depth: min(depth, maxDepth)))
      for child in children[comment.id] ?? [] {
        walk(child, depth: depth + 1)
      }
    }
    roots.forEach { walk($0, depth: 0) }
    return rows
  }
}

extension BoardPostSummary {
  func applying(_ vote: BoardVoteResponse) -> BoardPostSummary {
    BoardPostSummary(
      id: id, boardSlug: boardSlug, kind: kind, title: title, url: url, domain: domain, tags: tags,
      authorUsername: authorUsername, createdAt: createdAt, score: vote.score, commentCount: commentCount,
      participantCount: participantCount, viewCount: viewCount, viewerHasVoted: vote.voted,
      newCommentCount: newCommentCount
    )
  }

  /// Only http(s) links open; anything else stays plain text.
  var openableURL: URL? {
    guard let url, let parsed = URL(string: url), ["http", "https"].contains(parsed.scheme?.lowercased() ?? "") else {
      return nil
    }
    return parsed
  }
}

enum BoardAge {
  /// The compact "7h", "1d" age the board rows use.
  static func short(_ date: Date, now: Date = Date()) -> String {
    let seconds = now.timeIntervalSince(date)
    switch seconds {
    case ..<60: return String(localized: "now")
    case ..<3600: return "\(Int(seconds / 60))m"
    case ..<86400: return "\(Int(seconds / 3600))h"
    case ..<(30 * 86400): return "\(Int(seconds / 86400))d"
    default: return date.formatted(date: .abbreviated, time: .omitted)
    }
  }
}

struct BoardsPendingPost: Identifiable, Equatable {
  let id: UUID
}

@MainActor
@Observable
final class BoardsActivityModel {
  private(set) var items: [BoardNotification] = []
  private(set) var nextCursor: String?
  private(set) var isLoading = false
  /// Unread when the screen opened; kept so those rows stay highlighted after
  /// they are marked read.
  private(set) var highlighted: Set<UUID> = []
  var settings = BoardNotificationSettings.default
  var errorMessage: String?

  private let service: any BoardsServicing

  init(service: any BoardsServicing = Container.shared.boardsService()) {
    self.service = service
  }

  /// Loads the first page, then marks everything read.
  func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      let page = try await service.notifications(cursor: nil)
      items = page.items.filter { $0.kind != .other }
      nextCursor = page.nextCursor
      highlighted = Set(page.items.filter { !$0.isRead }.map(\.id))
      if page.unreadCount > 0 { try await service.markRead(ids: nil) }
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
    if let settings = try? await service.notificationSettings() { self.settings = settings }
  }

  func loadMore() async {
    guard let cursor = nextCursor, !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      let page = try await service.notifications(cursor: cursor)
      items.append(contentsOf: page.items.filter { $0.kind != .other })
      nextCursor = page.nextCursor
    } catch {
      // The row that asked for this page scrolled away; nothing went wrong.
      if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled { return }
      errorMessage = error.localizedDescription
    }
  }

  /// Bumped by every save, so only the newest one applies its answer. Without
  /// it, two quick toggles race: the first save's response, or its rollback
  /// on failure, lands after the second and puts the screen out of step with
  /// the server.
  private var saveGeneration = 0

  func save(_ settings: BoardNotificationSettings) async {
    saveGeneration += 1
    let generation = saveGeneration
    let previous = self.settings
    self.settings = settings
    do {
      let saved = try await service.updateNotificationSettings(settings)
      if generation == saveGeneration { self.settings = saved }
    } catch {
      guard generation == saveGeneration else { return }
      self.settings = previous
      errorMessage = error.localizedDescription
    }
  }
}
