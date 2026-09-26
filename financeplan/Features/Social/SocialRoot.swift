import Factory
import SwiftUI

/// The Friends tab: invite, pending requests and the friend list.
/// Leaderboards and messages join this screen in later phases.
struct SocialRoot: View {
  @Binding var pendingInviteCode: String?
  @InjectedObservable(\Container.socialStore) private var store
  @State private var isSearchPresented = false
  @State private var isInvitePresented = false
  @State private var redeemingInvite: InviteCodeItem?
  @State private var path = NavigationPath()

  var body: some View {
    NavigationStack(path: $path) {
      content
        .navigationTitle("Friends")
        .toolbar { toolbar }
        .navigationDestination(for: SocialUserSummary.self) { user in
          SocialProfileView(user: user)
        }
        .navigationDestination(for: SocialSettingsDestination.self) { destination in
          switch destination {
          case .privacy: SocialPrivacySettingsView()
          case .blocked: BlockedUsersView()
          }
        }
        .refreshable { await store.load() }
        .task {
          if !store.hasLoaded { await store.load() }
        }
        .sheet(isPresented: $isSearchPresented) { UserSearchView() }
        .sheet(isPresented: $isInvitePresented) { InviteFriendsView() }
        .sheet(item: $redeemingInvite) { item in InviteRedeemSheet(code: item.code) }
        .onChange(of: pendingInviteCode, initial: true) { _, code in
          guard let code else { return }
          pendingInviteCode = nil
          redeemingInvite = InviteCodeItem(code: code)
        }
        .alert(
          "Something went wrong",
          isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
        ) {
          Button("OK", role: .cancel) {}
        } message: {
          Text(store.errorMessage ?? "")
        }
    }
  }

  @ViewBuilder
  private var content: some View {
    if !store.hasLoaded, store.isLoading {
      ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      List {
        Section {
          Button { isInvitePresented = true } label: {
            Label("Invite friends", systemImage: "square.and.arrow.up")
          }
          Button { isSearchPresented = true } label: {
            Label("Find people by username", systemImage: "magnifyingglass")
          }
        } footer: {
          Text("Share your invite link on Instagram, Facebook, X or WhatsApp.")
        }

        if !store.incoming.isEmpty {
          Section("Requests") {
            ForEach(store.incoming) { request in
              IncomingRequestRow(request: request)
            }
          }
        }

        Section("Friends") {
          if store.friends.isEmpty {
            Text("No friends yet. Invite someone to compare progress and share ideas.")
              .typography(.caption)
              .foregroundStyle(.secondary)
          }
          ForEach(store.friends) { friend in
            NavigationLink(value: friend) { SocialUserRow(user: friend) }
          }
        }

        if !store.outgoing.isEmpty {
          Section("Sent") {
            ForEach(store.outgoing) { request in
              SocialUserRow(user: request.to) {
                Button("Cancel") { Task { await store.cancel(request) } }
                  .buttonStyle(.bordered)
                  .controlSize(.small)
              }
            }
          }
        }
      }
    }
  }

  @ToolbarContentBuilder
  private var toolbar: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      Button { isSearchPresented = true } label: {
        Label("Add friend", systemImage: "person.badge.plus")
      }
    }
    ToolbarItem(placement: .topBarTrailing) {
      Menu {
        Button { path.append(SocialSettingsDestination.privacy) } label: {
          Label("Privacy", systemImage: "hand.raised")
        }
        Button { path.append(SocialSettingsDestination.blocked) } label: {
          Label("Blocked people", systemImage: "nosign")
        }
      } label: {
        Label("Friend settings", systemImage: "ellipsis.circle")
      }
    }
  }
}

enum SocialSettingsDestination: Hashable {
  case privacy
  case blocked
}

private struct InviteCodeItem: Identifiable {
  let code: String
  var id: String { code }
}

private struct IncomingRequestRow: View {
  let request: FriendRequest
  @InjectedObservable(\Container.socialStore) private var store
  @State private var isWorking = false

  var body: some View {
    NavigationLink(value: request.from) {
      SocialUserRow(user: request.from) {
        HStack(spacing: 8) {
          Button { respond(accept: false) } label: {
            Label("Decline", systemImage: "xmark").labelStyle(.iconOnly)
          }
          .buttonStyle(.bordered)
          Button { respond(accept: true) } label: {
            Label("Accept", systemImage: "checkmark").labelStyle(.iconOnly)
          }
          .buttonStyle(.borderedProminent)
        }
        .controlSize(.small)
        .disabled(isWorking)
      }
    }
  }

  private func respond(accept: Bool) {
    Task {
      isWorking = true
      _ = await store.respond(to: request, accept: accept)
      isWorking = false
    }
  }
}
