import Factory
import SwiftUI

struct UserSearchView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var query = ""
  @State private var results: [SocialUserSummary] = []
  @State private var isSearching = false
  @State private var searchError: String?
  private let service: any SocialServicing = Container.shared.socialService()

  static let minimumQueryLength = 2

  var body: some View {
    NavigationStack {
      List {
        if let searchError {
          Text(searchError).foregroundStyle(.secondary)
        } else if trimmedQuery.count >= Self.minimumQueryLength, results.isEmpty, !isSearching {
          Text("No one found with that username.").foregroundStyle(.secondary)
        }
        ForEach(results) { user in
          NavigationLink(value: user) {
            SocialUserRow(user: user) { FriendActionButton(user: user) }
          }
        }
      }
      .overlay {
        if isSearching { ProgressView() }
      }
      .navigationTitle("Find friends")
      .navigationBarTitleDisplayMode(.inline)
      .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Username")
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .navigationDestination(for: SocialUserSummary.self) { user in
        SocialProfileView(user: user)
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
      }
      .task(id: trimmedQuery) { await search(trimmedQuery) }
    }
  }

  private var trimmedQuery: String {
    query.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "@"))
  }

  /// Debounced by `task(id:)`: typing cancels the pending search.
  private func search(_ text: String) async {
    guard text.count >= Self.minimumQueryLength else {
      results = []
      searchError = nil
      return
    }
    try? await Task.sleep(for: .milliseconds(300))
    guard !Task.isCancelled else { return }
    isSearching = true
    defer { isSearching = false }
    do {
      let found = try await service.searchUsers(query: text)
      guard !Task.isCancelled else { return }
      results = found
      searchError = nil
    } catch {
      guard !Task.isCancelled else { return }
      searchError = error.localizedDescription
    }
  }
}
