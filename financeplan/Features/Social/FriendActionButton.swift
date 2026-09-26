import Factory
import SwiftUI

/// The one relationship action that fits the current state: add, accept,
/// cancel a sent request, or nothing when already friends.
struct FriendActionButton: View {
  let user: SocialUserSummary
  @InjectedObservable(\Container.socialStore) private var store
  @State private var isWorking = false

  var body: some View {
    let status = store.status(of: user.id) == .none ? user.friendshipStatus : store.status(of: user.id)
    Group {
      switch status {
      case .none:
        button("Add", systemImage: "person.badge.plus") { _ = await store.sendRequest(to: user) }
          .buttonStyle(.borderedProminent)
      case .incomingPending:
        button("Accept", systemImage: "checkmark") {
          if let request = store.incoming.first(where: { $0.from.id == user.id }) {
            _ = await store.respond(to: request, accept: true)
          }
        }
        .buttonStyle(.borderedProminent)
      case .outgoingPending:
        button("Requested", systemImage: "clock") {
          if let request = store.outgoing.first(where: { $0.to.id == user.id }) {
            await store.cancel(request)
          }
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Cancels the friend request")
      case .friends:
        Label("Friends", systemImage: "checkmark.circle.fill")
          .labelStyle(.iconOnly)
          .foregroundStyle(AppTheme.Colors.tint)
          .accessibilityLabel("Friends")
      case .blocked:
        EmptyView()
      }
    }
    .controlSize(.small)
    .disabled(isWorking)
  }

  private func button(_ title: LocalizedStringKey, systemImage: String, action: @escaping () async -> Void) -> some View {
    Button {
      Task {
        isWorking = true
        await action()
        isWorking = false
      }
    } label: {
      Label(title, systemImage: systemImage)
    }
  }
}
