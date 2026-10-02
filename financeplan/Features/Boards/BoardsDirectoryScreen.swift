import Factory
import StockPlanShared
import SwiftUI

/// The Boards tab. Banned viewers see an explanation instead of the boards;
/// everyone else sees the directory.
struct BoardsRoot: View {
  @InjectedObservable(\Container.boardsViewerStore) private var viewer

  var body: some View {
    Group {
      if viewer.isBanned {
        ContentUnavailableView(
          "Boards unavailable",
          systemImage: "hand.raised",
          description: Text("Your access to Norviq Boards has been removed. The rest of Norviq works as usual.")
        )
      } else {
        BoardsDirectoryScreen()
      }
    }
    .task { await viewer.load() }
  }
}

struct BoardsDirectoryScreen: View {
  @InjectedObservable(\Container.boardsViewerStore) private var viewer
  @State private var model = BoardsDirectoryModel()
  @State private var isCreating = false

  var body: some View {
    List {
      BoardsViewerBanner()
      if model.boards.isEmpty, !model.isLoading {
        ContentUnavailableView("No boards yet", systemImage: "bubble.left.and.text.bubble.right", description: Text("Start the first one."))
      }
      ForEach(model.boards) { board in
        NavigationLink {
          BoardScreen(board: board)
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
              Text(board.name).font(.headline)
              Text("/\(board.slug)").font(.caption).foregroundStyle(.secondary)
              Spacer()
              Text(BoardAge.short(board.lastActivityAt)).font(.caption).foregroundStyle(.secondary)
            }
            if !board.description.isEmpty {
              Text(board.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            Text("\(board.postCount) posts").font(.caption2).foregroundStyle(.secondary)
          }
          .padding(.vertical, 2)
        }
        .accessibilityIdentifier("boards.board.\(board.slug)")
        .task {
          if board.id == model.boards.last?.id { await model.loadMore() }
        }
      }
    }
    .navigationTitle("Boards")
    .refreshable {
      await viewer.load()
      await model.load()
    }
    .task { await model.load() }
    .toolbar {
      if viewer.canWrite {
        ToolbarItem(placement: .primaryAction) {
          Button("New board", systemImage: "plus") { isCreating = true }
            .accessibilityIdentifier("boards.create")
        }
      }
    }
    .sheet(isPresented: $isCreating) {
      CreateBoardSheet(model: model)
    }
    .alert("Something went wrong", isPresented: boardsErrorBinding($model.errorMessage)) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(model.errorMessage ?? "")
    }
  }
}

/// Explains what stands between the viewer and posting, with the fix.
struct BoardsViewerBanner: View {
  @InjectedObservable(\Container.boardsViewerStore) private var viewer
  @State private var showGuidelines = false

  var body: some View {
    if viewer.isMuted {
      Label(mutedText, systemImage: "speaker.slash")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    } else if viewer.needsUsername {
      Label("Pick a username in your profile to post.", systemImage: "person.crop.circle.badge.questionmark")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    } else if viewer.needsGuidelines {
      Button {
        showGuidelines = true
      } label: {
        Label("Read the community guidelines to start posting", systemImage: "checkmark.shield")
      }
      .sheet(isPresented: $showGuidelines) { BoardsGuidelinesSheet() }
    }
  }

  private var mutedText: String {
    if let until = viewer.mutedUntil {
      return String(localized: "You're muted until \(until.formatted(date: .abbreviated, time: .shortened)). You can still read, report and block.")
    }
    return String(localized: "You're muted. You can still read, report and block.")
  }
}

/// A Bool binding over an optional error message, for `.alert`.
@MainActor
func boardsErrorBinding(_ message: Binding<String?>) -> Binding<Bool> {
  Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })
}
