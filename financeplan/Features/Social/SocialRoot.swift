import Factory
import SwiftUI

/// The Friends tab: friends-only leaderboards (when the server turns them on),
/// invites, pending requests and the friend list. Messages join in Phase 4.
struct SocialRoot: View {
  @Binding var pendingInviteCode: String?
  @InjectedObservable(\Container.socialStore) private var store
  @State private var isSearchPresented = false
  @State private var isInvitePresented = false
  @State private var isContactsPresented = false
  @State private var isXImportPresented = false
  @State private var isFacebookImportPresented = false
  @State private var redeemingInvite: InviteCodeItem?
  @State private var section: SocialSection = .friends
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
        .sheet(isPresented: $isContactsPresented) { ContactsDiscoveryView() }
        .sheet(isPresented: $isXImportPresented) { XImportView() }
        .sheet(isPresented: $isFacebookImportPresented) { FacebookImportView() }
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
    if store.config.leaderboards {
      VStack(spacing: 0) {
        Picker("Section", selection: $section) {
          ForEach(SocialSection.allCases) { item in
            Text(item.title).tag(item)
          }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)

        switch section {
        case .leaderboard:
          LeaderboardView(onInvite: { isInvitePresented = true })
        case .friends:
          friendsContent
        }
      }
    } else {
      friendsContent
    }
  }

  @ViewBuilder
  private var friendsContent: some View {
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
          if store.config.contactsDiscovery {
            Button { isContactsPresented = true } label: {
              Label("Find friends from contacts", systemImage: "person.crop.circle.badge.checkmark")
            }
          }
          if store.config.xImport {
            Button { isXImportPresented = true } label: {
              Label("Find people you follow on X", systemImage: "person.2.wave.2")
            }
          }
          if store.config.facebookImport && FacebookConnect.isAvailable {
            Button { isFacebookImportPresented = true } label: {
              Label("Find friends from Facebook", systemImage: "person.2.badge.key")
            }
          }
        } footer: {
          Text("Text your invite link or share it on Messenger, Instagram, X or WhatsApp.")
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

enum SocialSection: String, CaseIterable, Identifiable {
  case leaderboard
  case friends

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .leaderboard: "Leaderboard"
    case .friends: "Friends"
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
