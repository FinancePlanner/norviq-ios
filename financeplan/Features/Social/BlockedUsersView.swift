import Factory
import SwiftUI

struct BlockedUsersView: View {
  @InjectedObservable(\Container.socialStore) private var store

  var body: some View {
    List {
      if store.blocked.isEmpty {
        Text("You haven't blocked anyone.").foregroundStyle(.secondary)
      }
      ForEach(store.blocked) { user in
        SocialUserRow(user: user) {
          Button("Unblock") { Task { await store.unblock(user) } }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
      }
    }
    .navigationTitle("Blocked people")
    .task { await store.loadBlocked() }
  }
}
