import Factory
import StockPlanShared
import SwiftUI

struct BoardPostDetailScreen: View {
  @InjectedObservable(\Container.boardsViewerStore) private var viewer
  @Environment(\.openURL) private var openURL
  @State private var model: BoardPostDetailModel
  @State private var draft = ""
  @State private var replyTo: BoardComment?
  @State private var reportTarget: BoardReportTarget?
  @State private var moderationUsername: String?
  @State private var isSending = false
  @FocusState private var composerFocused: Bool
  private let title: String

  init(postId: UUID, title: String) {
    _model = State(initialValue: BoardPostDetailModel(postId: postId))
    self.title = title
  }

  var body: some View {
    List {
      if let detail = model.detail {
        Section {
          BoardPostRow(post: detail.post, canVote: viewer.canWrite) {
            Task { await model.vote() }
          }
          if let link = detail.post.openableURL {
            Button {
              openURL(link)
            } label: {
              Label(detail.post.domain ?? link.absoluteString, systemImage: "arrow.up.right.square")
            }
          }
          if let body = detail.body, !body.isEmpty {
            Text(body).font(.body).textSelection(.enabled)
          }
        }
        Section(model.thread.isEmpty ? "No comments yet" : "Comments") {
          ForEach(model.thread) { row in
            commentRow(row)
          }
        }
      } else if model.isLoading {
        ProgressView()
      }
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .refreshable { await model.load() }
    .task { await model.load() }
    .safeAreaInset(edge: .bottom) {
      if viewer.canWrite { composer }
    }
    .sheet(item: $reportTarget) { BoardReportSheet(target: $0) }
    .sheet(item: Binding(get: { moderationUsername.map(BoardsUsername.init) }, set: { moderationUsername = $0?.value })) {
      BoardModerationSheet(username: $0.value)
    }
    .toolbar {
      if let post = model.detail?.post {
        ToolbarItem(placement: .secondaryAction) {
          Button("Report post", systemImage: "flag") { reportTarget = .post(post.id, title: post.title) }
        }
      }
    }
    .alert("Something went wrong", isPresented: errorAlertBinding($model.errorMessage)) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(model.errorMessage ?? "")
    }
  }

  private func commentRow(_ row: BoardThreadRow) -> some View {
    let comment = row.comment
    let isMine = comment.authorUsername != nil && comment.authorUsername == viewer.username
    return VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        if comment.isDeleted {
          Text("[deleted]").foregroundStyle(.secondary)
        } else {
          Text(comment.authorUsername ?? "").foregroundStyle(AppTheme.Colors.tint)
        }
        Text(BoardAge.short(comment.createdAt)).foregroundStyle(.secondary)
      }
      .font(.caption)
      if !comment.isDeleted {
        Text(comment.body).font(.subheadline).textSelection(.enabled)
      }
    }
    .padding(.leading, CGFloat(row.depth) * 12)
    .overlay(alignment: .leading) {
      if row.depth > 0 {
        Rectangle().fill(.quaternary).frame(width: 2).padding(.leading, CGFloat(row.depth) * 12 - 8)
      }
    }
    .contextMenu {
      if !comment.isDeleted {
        if viewer.canWrite, comment.depth < BoardThread.maxDepth {
          Button("Reply", systemImage: "arrowshape.turn.up.left") {
            replyTo = comment
            composerFocused = true
          }
        }
        Button("Report", systemImage: "flag") { reportTarget = .comment(comment.id, excerpt: comment.body) }
        if isMine || viewer.isAdmin {
          Button("Delete", systemImage: "trash", role: .destructive) { Task { await model.deleteComment(comment.id) } }
        }
        if viewer.isAdmin, let author = comment.authorUsername, !isMine {
          Button("Mute or ban \(author)", systemImage: "speaker.slash") { moderationUsername = author }
        }
      }
    }
    .accessibilityIdentifier("boards.comment.\(comment.id.uuidString)")
  }

  private var composer: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let replyTo {
        HStack {
          Text("Replying to \(replyTo.authorUsername ?? "comment")").font(.caption).foregroundStyle(.secondary)
          Spacer()
          Button("Cancel", systemImage: "xmark") { self.replyTo = nil }
            .labelStyle(.iconOnly)
            .font(.caption)
        }
      }
      HStack(alignment: .bottom) {
        TextField("Add a comment", text: $draft, axis: .vertical)
          .lineLimit(1...5)
          .focused($composerFocused)
          .textFieldStyle(.roundedBorder)
        Button {
          Task { await send() }
        } label: {
          Image(systemName: "arrow.up.circle.fill").font(.title2)
        }
        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        .accessibilityLabel("Send comment")
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .background(.bar)
  }

  private func send() async {
    isSending = true
    defer { isSending = false }
    if await model.comment(draft, parentId: replyTo?.id) {
      draft = ""
      replyTo = nil
      composerFocused = false
    }
  }
}
