import Factory
import StockPlanShared
import SwiftUI

/// Replies to the viewer and upvotes on their posts, newest first, with the
/// push toggles on top. Opening it marks everything read.
struct BoardsActivityScreen: View {
  @InjectedObservable(\Container.boardsViewerStore) private var viewer
  @State private var model = BoardsActivityModel()

  var body: some View {
    List {
      Section {
        Toggle("Replies to me", isOn: binding(\.replyPush))
        Toggle("Upvotes on my posts", isOn: binding(\.upvotePush))
      } header: {
        Text("Push notifications")
      } footer: {
        Text("Upvote pushes are held to one an hour per post. This list always keeps everything.")
      }
      Section {
        if model.items.isEmpty, !model.isLoading {
          Text("Nothing yet. Replies and upvotes on your posts show up here.")
            .foregroundStyle(.secondary)
        }
        ForEach(model.items) { item in
          NavigationLink {
            BoardPostDetailScreen(postId: item.postId, title: item.postTitle)
          } label: {
            BoardsActivityRow(item: item, highlighted: model.highlighted.contains(item.id))
          }
          .task {
            if item.id == model.items.last?.id { await model.loadMore() }
          }
        }
      }
    }
    .navigationTitle("Activity")
    .refreshable { await reload() }
    .task { await reload() }
    .alert("Something went wrong", isPresented: errorAlertBinding($model.errorMessage)) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(model.errorMessage ?? "")
    }
  }

  private func reload() async {
    await model.load()
    // A failed load marked nothing read, so the badge must stay.
    if model.errorMessage == nil { viewer.clearUnread() }
  }

  private func binding(_ keyPath: KeyPath<BoardNotificationSettings, Bool>) -> Binding<Bool> {
    Binding(
      get: { model.settings[keyPath: keyPath] },
      set: { value in
        let current = model.settings
        let updated = keyPath == \BoardNotificationSettings.replyPush
          ? BoardNotificationSettings(replyPush: value, upvotePush: current.upvotePush)
          : BoardNotificationSettings(replyPush: current.replyPush, upvotePush: value)
        Task { await model.save(updated) }
      }
    )
  }
}

struct BoardsActivityRow: View {
  let item: BoardNotification
  let highlighted: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: item.kind == .upvote ? "arrowshape.up.fill" : "bubble.left.fill")
        .foregroundStyle(AppTheme.Colors.tint)
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        headline.font(.subheadline)
        if let excerpt = item.excerpt, !excerpt.isEmpty {
          Text(excerpt).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        Text(BoardAge.short(item.createdAt)).font(.caption2).foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
      if highlighted {
        Circle().fill(AppTheme.Colors.tint).frame(width: 8, height: 8).accessibilityLabel("New")
      }
    }
    .padding(.vertical, 2)
  }

  /// One localized sentence per kind, so a translation can order the actor,
  /// the verb and the post title however its grammar needs.
  private var headline: Text {
    let actor = Text(item.actorUsername ?? String(localized: "Someone")).foregroundStyle(AppTheme.Colors.tint)
    let title = Text(item.postTitle).font(.subheadline.weight(.semibold))
    return item.kind == .upvote
      ? Text("\(actor) upvoted \(title)", comment: "Boards activity row. First placeholder: who upvoted. Second: the post title.")
      : Text("\(actor) replied on \(title)", comment: "Boards activity row. First placeholder: who replied. Second: the post title.")
  }
}
