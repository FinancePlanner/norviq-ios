import Factory
import SwiftUI

/// Where the user's XP came from, newest first.
struct XPHistoryView: View {
  @State private var events: [XPEvent] = []
  @State private var nextCursor: String?
  @State private var isLoading = false
  @State private var hasLoaded = false
  @State private var errorMessage: String?

  private let service: any GamificationServicing = Container.shared.gamificationService()

  var body: some View {
    List {
      if hasLoaded, events.isEmpty {
        ContentUnavailableView(
          "No XP yet",
          systemImage: "sparkles",
          description: Text("Check in daily and stay on budget to earn XP.")
        )
      }
      ForEach(events) { event in
        HStack(spacing: 12) {
          Image(systemName: event.type.symbol)
            .foregroundStyle(AppTheme.Colors.tint)
            .frame(width: 24)
          VStack(alignment: .leading, spacing: 2) {
            Text(event.type.title)
              .typography(.label, weight: .semibold)
            Text(event.createdAt, format: .dateTime.day().month().year())
              .typography(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Text("+\(event.points) XP")
            .typography(.label, weight: .semibold)
            .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
      }
      if nextCursor != nil {
        Button("Load more") { Task { await loadMore() } }
          .disabled(isLoading)
      }
      if let errorMessage {
        Text(errorMessage)
          .typography(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .navigationTitle("XP history")
    .overlay {
      if isLoading, events.isEmpty { ProgressView() }
    }
    .refreshable { await reload() }
    .task {
      if !hasLoaded { await reload() }
    }
  }

  private func reload() async {
    events = []
    nextCursor = nil
    await fetch(cursor: nil)
  }

  private func loadMore() async {
    guard let nextCursor, !isLoading else { return }
    await fetch(cursor: nextCursor)
  }

  private func fetch(cursor: String?) async {
    isLoading = true
    defer { isLoading = false }
    do {
      let page = try await service.xpEvents(cursor: cursor)
      events.append(contentsOf: page.events)
      nextCursor = page.nextCursor
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
    hasLoaded = true
  }
}
