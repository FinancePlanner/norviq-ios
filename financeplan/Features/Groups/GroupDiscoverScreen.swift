import Factory
import StockPlanShared
import SwiftUI

/// Public groups. Searching `$AAPL` finds groups about that ticker; an empty
/// search shows the most active ones.
struct GroupDiscoverScreen: View {
  @InjectedObservable(\Container.groupsStore) private var store
  let onOpen: (UUID) -> Void
  @State private var query = ""
  @State private var results: [GroupSummary] = []
  @State private var nextCursor: String?
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var previewing: GroupSummary?

  private let service: any GroupsServicing = Container.shared.groupsService()

  var body: some View {
    List {
      if results.isEmpty, !isLoading {
        ContentUnavailableView(
          query.isEmpty ? "No public groups yet" : "No groups found",
          systemImage: "magnifyingglass",
          description: Text(query.isEmpty ? "Start one and make it public." : "Try a ticker like $AAPL.")
        )
      }
      ForEach(results) { group in
        Button {
          if group.membership != nil {
            onOpen(group.id)
          } else {
            previewing = group
          }
        } label: {
          GroupSummaryRow(group: group)
        }
        .buttonStyle(.plain)
        .task {
          if group.id == results.last?.id { await loadMore() }
        }
      }
    }
    .navigationTitle("Discover")
    .searchable(text: $query, prompt: "Search groups or $TICKER")
    .task(id: query) {
      // Typing settles before the request goes out.
      try? await Task.sleep(for: .milliseconds(300))
      guard !Task.isCancelled else { return }
      await search()
    }
    .refreshable { await search() }
    .sheet(item: $previewing) { group in
      GroupPreviewSheet(group: group) { joined in
        previewing = nil
        onOpen(joined.group.id)
      }
    }
    .alert("Something went wrong", isPresented: errorAlertBinding($errorMessage)) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "")
    }
  }

  /// `$aapl` searches by ticker; anything else by name.
  static func parameters(for query: String) -> (query: String?, ticker: String?) {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("$") {
      let ticker = CreateGroupSheet.normalizedTicker(String(trimmed.dropFirst()))
      return (nil, ticker.isEmpty ? nil : ticker)
    }
    return (trimmed.isEmpty ? nil : trimmed, nil)
  }

  private func search() async {
    isLoading = true
    defer { isLoading = false }
    let parameters = Self.parameters(for: query)
    do {
      let page = try await service.discover(query: parameters.query, ticker: parameters.ticker, tickers: [], cursor: nil)
      results = page.items
      nextCursor = page.nextCursor
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func loadMore() async {
    guard let cursor = nextCursor, !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    let parameters = Self.parameters(for: query)
    if let page = try? await service.discover(query: parameters.query, ticker: parameters.ticker, tickers: [], cursor: cursor) {
      results.append(contentsOf: page.items.filter { item in !results.contains { $0.id == item.id } })
      nextCursor = page.nextCursor
    }
  }
}

/// A public group before joining.
struct GroupPreviewSheet: View {
  @InjectedObservable(\Container.groupsStore) private var store
  @InjectedObservable(\Container.boardsViewerStore) private var viewer
  @Environment(\.dismiss) private var dismiss
  let group: GroupSummary
  let onJoined: (GroupDetail) -> Void
  @State private var isJoining = false
  @State private var errorMessage: String?
  @State private var showGuidelines = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack(spacing: 12) {
            GroupIcon(emoji: group.iconEmoji, name: group.name, size: 52)
            VStack(alignment: .leading, spacing: 4) {
              Text(group.name).font(.title3.weight(.semibold))
              Text("^[\(group.memberCount) member](inflect: true)").font(.subheadline).foregroundStyle(.secondary)
            }
          }
          if !group.description.isEmpty { Text(group.description) }
        }
        Section {
          Button("Join group") { Task { await join() } }
            .disabled(isJoining)
            .accessibilityIdentifier("groups.preview.join")
        } footer: {
          Text("Messages in public groups can be read by anyone who joins. Notifications start off; turn them on in the group's info.")
        }
        if let errorMessage {
          Section { Text(errorMessage).foregroundStyle(.red) }
        }
      }
      .navigationTitle("Group")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
      }
      .sheet(isPresented: $showGuidelines) { BoardsGuidelinesSheet() }
    }
  }

  private func join() async {
    if viewer.needsGuidelines {
      showGuidelines = true
      return
    }
    isJoining = true
    defer { isJoining = false }
    do {
      onJoined(try await store.join(group.id))
    } catch {
      errorMessage = GroupJoinSheet.message(for: error)
    }
  }
}
