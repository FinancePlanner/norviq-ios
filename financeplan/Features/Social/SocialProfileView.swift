import Factory
import SwiftUI

/// Someone's profile as their privacy settings allow, with the relationship
/// action and the safety actions (report, block) App Review expects on any
/// user-generated profile.
struct SocialProfileView: View {
  let user: SocialUserSummary
  @InjectedObservable(\Container.socialStore) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var profile: SocialProfile?
  @State private var isReportPresented = false
  @State private var isBlockConfirmationPresented = false
  @State private var isUnfriendConfirmationPresented = false
  private let service: any SocialServicing = Container.shared.socialService()

  var body: some View {
    List {
      Section {
        VStack(spacing: 12) {
          SocialAvatar(user: user, size: 88)
          Text(user.title).typography(.title)
          Text("@\(user.username)").typography(.caption).foregroundStyle(.secondary)
          FriendActionButton(user: user)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
      }

      if let profile, hasStats(profile) {
        Section("Progress") {
          if let streak = profile.streakDays {
            LabeledContent("Streak", value: String(localized: "\(streak) days"))
          }
          if let level = profile.xpLevel {
            LabeledContent("Level", value: "\(level)")
          }
          if let badges = profile.badgeCount {
            LabeledContent("Badges", value: "\(badges)")
          }
        }
      }

      if let mutual = user.mutualFriendCount, mutual > 0 {
        Section {
          Text("\(mutual) mutual friends").foregroundStyle(.secondary)
        }
      }
    }
    .navigationTitle(user.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          if store.status(of: user.id) == .friends {
            Button(role: .destructive) { isUnfriendConfirmationPresented = true } label: {
              Label("Remove friend", systemImage: "person.badge.minus")
            }
          }
          Button { isReportPresented = true } label: {
            Label("Report", systemImage: "exclamationmark.bubble")
          }
          Button(role: .destructive) { isBlockConfirmationPresented = true } label: {
            Label("Block", systemImage: "nosign")
          }
        } label: {
          Label("More", systemImage: "ellipsis.circle")
        }
      }
    }
    .task { profile = try? await service.profile(userId: user.id) }
    .sheet(isPresented: $isReportPresented) {
      ReportSheet(user: user)
    }
    .confirmationDialog(
      "Block \(user.title)?",
      isPresented: $isBlockConfirmationPresented,
      titleVisibility: .visible
    ) {
      Button("Block", role: .destructive) {
        Task {
          await store.block(user)
          dismiss()
        }
      }
    } message: {
      Text("They won't be able to find you, message you or see your progress. They aren't told you blocked them.")
    }
    .confirmationDialog(
      "Remove \(user.title) from friends?",
      isPresented: $isUnfriendConfirmationPresented,
      titleVisibility: .visible
    ) {
      Button("Remove friend", role: .destructive) {
        Task { await store.unfriend(user) }
      }
    }
  }

  private func hasStats(_ profile: SocialProfile) -> Bool {
    profile.streakDays != nil || profile.xpLevel != nil || profile.badgeCount != nil
  }
}
