import Factory
import StockPlanShared
import SwiftUI

/// One board, laid out like the Men of Hunger board: New / Top / Comments,
/// Ask and Show filters, and rows with an upvote arrow, title and domain, tags,
/// author and age, then comments, participants and views.
struct BoardScreen: View {
  @InjectedObservable(\Container.boardsViewerStore) private var viewer
  @Environment(\.dismiss) private var dismiss
  @State private var model: BoardFeedModel
  @State private var isComposing = false
  @State private var reportTarget: BoardReportTarget?
  @State private var moderationUsername: String?
  @State private var blockUsername: String?
  @State private var confirmDeleteBoard = false

  init(board: BoardSummary) {
    _model = State(initialValue: BoardFeedModel(board: board))
  }

  var body: some View {
    List {
      Section {
        if !model.board.description.isEmpty {
          Text(model.board.description).font(.subheadline).foregroundStyle(.secondary)
        }
        BoardsViewerBanner()
        filters
      }
      Section {
        if model.posts.isEmpty, !model.isLoading {
          Text("Nothing here yet.").foregroundStyle(.secondary)
        }
        ForEach(model.posts) { post in
          NavigationLink {
            BoardPostDetailScreen(postId: post.id, title: post.title)
          } label: {
            BoardPostRow(post: post, canVote: viewer.canWrite) {
              Task { await model.vote(post) }
            } onTag: { tag in
              model.tag = tag
              Task { await model.load() }
            }
          }
          .contextMenu { menu(for: post) }
          .task {
            if post.id == model.posts.last?.id { await model.loadMore() }
          }
        }
      }
    }
    .navigationTitle(model.board.name)
    .refreshable { await model.load() }
    .task { await model.load() }
    .toolbar {
      if viewer.canWrite {
        ToolbarItem(placement: .primaryAction) {
          Button("Post", systemImage: "square.and.pencil") { isComposing = true }
            .accessibilityIdentifier("boards.post")
        }
      }
      if viewer.isAdmin {
        ToolbarItem(placement: .secondaryAction) {
          Button("Delete board", systemImage: "trash", role: .destructive) { confirmDeleteBoard = true }
        }
      }
    }
    .sheet(isPresented: $isComposing) {
      ComposeBoardPostSheet(board: model.board) { model.prepend($0) }
    }
    .sheet(item: $reportTarget) { BoardReportSheet(target: $0) }
    .sheet(item: Binding(get: { moderationUsername.map(BoardsUsername.init) }, set: { moderationUsername = $0?.value })) {
      BoardModerationSheet(username: $0.value)
    }
    .confirmationDialog(
      "Block \(blockUsername ?? "")?",
      isPresented: Binding(get: { blockUsername != nil }, set: { if !$0 { blockUsername = nil } }),
      titleVisibility: .visible
    ) {
      Button("Block", role: .destructive) {
        guard let username = blockUsername else { return }
        Task { await block(username) }
      }
    } message: {
      Text("You won't see each other's posts or comments, and any friendship ends.")
    }
    .confirmationDialog("Delete this board and hide all its posts?", isPresented: $confirmDeleteBoard, titleVisibility: .visible) {
      Button("Delete board", role: .destructive) { Task { await deleteBoard() } }
    }
    .alert("Something went wrong", isPresented: errorAlertBinding($model.errorMessage)) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(model.errorMessage ?? "")
    }
  }

  private var filters: some View {
    VStack(alignment: .leading, spacing: 8) {
      Picker("Sort", selection: Binding(get: { model.sort }, set: { model.sort = $0; Task { await model.load() } })) {
        Text("New").tag(BoardPostSort.new)
        Text("Top").tag(BoardPostSort.top)
        Text("Comments").tag(BoardPostSort.active)
      }
      .pickerStyle(.segmented)
      HStack {
        filterChip("Ask", selected: model.kind == .ask) { Task { await model.toggleKind(.ask) } }
        filterChip("Show", selected: model.kind == .show) { Task { await model.toggleKind(.show) } }
        if let tag = model.tag {
          filterChip("#\(tag) ✕", selected: true) {
            model.tag = nil
            Task { await model.load() }
          }
        }
      }
    }
  }

  private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(title, action: action)
      .buttonStyle(.bordered)
      .tint(selected ? AppTheme.Colors.tint : .secondary)
      .controlSize(.small)
  }

  @ViewBuilder
  private func menu(for post: BoardPostSummary) -> some View {
    Button("Report", systemImage: "flag") { reportTarget = .post(post.id, title: post.title) }
    if let author = post.authorUsername, author != currentUsername, !post.aiGenerated {
      Button("Block \(author)", systemImage: "nosign") { blockUsername = author }
    }
    if viewer.isAdmin || (!post.aiGenerated && post.authorUsername != nil && post.authorUsername == currentUsername) {
      Button("Delete post", systemImage: "trash", role: .destructive) { Task { await model.delete(post) } }
    }
    if viewer.isAdmin, let author = post.authorUsername, author != currentUsername, !post.aiGenerated {
      Button("Mute or ban \(author)", systemImage: "speaker.slash") { moderationUsername = author }
    }
  }

  private var currentUsername: String? { viewer.username }

  private func block(_ username: String) async {
    do {
      try await Container.shared.boardsService().block(username: username)
      model.hidePosts(by: username)
    } catch {
      model.errorMessage = error.localizedDescription
    }
  }

  private func deleteBoard() async {
    do {
      try await Container.shared.boardsService().deleteBoard(slug: model.board.slug)
      dismiss()
    } catch {
      model.errorMessage = error.localizedDescription
    }
  }
}

struct BoardPostRow: View {
  let post: BoardPostSummary
  let canVote: Bool
  let onVote: () -> Void
  var onTag: (String) -> Void = { _ in }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      BoardVoteButton(score: post.score, voted: post.viewerHasVoted, enabled: canVote, action: onVote)
      VStack(alignment: .leading, spacing: 4) {
        Text(titleText).font(.body.weight(.semibold))
        byline
        if !visibleTags.isEmpty {
          tagLine
        }
        stats
      }
    }
    .padding(.vertical, 4)
    .accessibilityIdentifier("boards.post.\(post.id.uuidString)")
  }

  /// AI badge, author and age on one line.
  private var byline: some View {
    HStack(spacing: 4) {
      if post.aiGenerated {
        Text("AI")
          .font(.caption2.weight(.semibold))
          .padding(.horizontal, 4)
          .background(AppTheme.Colors.tint.opacity(0.15), in: Capsule())
          .foregroundStyle(AppTheme.Colors.tint)
          .accessibilityLabel("AI generated")
      }
      if let author = post.authorUsername {
        Text(author).foregroundStyle(AppTheme.Colors.tint)
        Text(verbatim: "·")
      }
      Text(BoardAge.short(post.createdAt))
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .lineLimit(1)
  }

  /// Tags as plain #words that never wrap mid-word. The "ai" tag repeats the
  /// badge, so it is left out.
  private var tagLine: some View {
    HStack(spacing: 8) {
      ForEach(visibleTags, id: \.self) { tag in
        Button("#\(tag)") { onTag(tag) }
          .buttonStyle(.borderless)
          .foregroundStyle(AppTheme.Colors.tint)
          .fixedSize()
      }
    }
    .font(.caption)
    .lineLimit(1)
  }

  private var stats: some View {
    HStack(spacing: 12) {
      Label("\(post.commentCount)", systemImage: "bubble.left")
      if let new = post.newCommentCount, new > 0 {
        Text("\(new) new").foregroundStyle(AppTheme.Colors.tint)
      }
      Label("\(post.participantCount)", systemImage: "person")
      Label("\(post.viewCount)", systemImage: "eye")
    }
    .font(.caption2)
    .foregroundStyle(.secondary)
    .labelStyle(.titleAndIcon)
    .accessibilityElement(children: .combine)
  }

  private var visibleTags: [String] {
    post.aiGenerated ? post.tags.filter { $0.lowercased() != "ai" } : post.tags
  }

  private var titleText: AttributedString {
    var title = AttributedString(prefix + post.title)
    if let domain = post.domain {
      var suffix = AttributedString("  \(domain)")
      suffix.font = .caption
      suffix.foregroundColor = .secondary
      title.append(suffix)
    }
    return title
  }

  private var prefix: String {
    switch post.kind {
    case .ask: return String(localized: "Ask: ")
    case .show: return String(localized: "Show: ")
    case .link, .text: return ""
    }
  }
}

struct BoardVoteButton: View {
  let score: Int
  let voted: Bool
  let enabled: Bool
  let action: () -> Void

  var body: some View {
    VStack(spacing: 2) {
      Button(action: action) {
        Image(systemName: voted ? "arrowshape.up.fill" : "arrowshape.up")
          .foregroundStyle(voted ? AppTheme.Colors.tint : .secondary)
      }
      .buttonStyle(.borderless)
      .disabled(!enabled)
      .accessibilityLabel(voted ? "Remove upvote" : "Upvote")
      if score > 0 {
        Text("\(score)").font(.caption2.monospacedDigit())
      }
    }
    .frame(width: 28)
  }
}

/// String wrapper so a username can drive `.sheet(item:)`.
struct BoardsUsername: Identifiable {
  let value: String
  var id: String { value }
}
