import Factory
import SwiftUI

/// Everything a friend has unlocked that they let friends see.
struct FriendAchievementsView: View {
  let user: SocialUserSummary
  @State private var unlocks: [AchievementUnlock]?
  @State private var error: String?
  private let service: any SocialServicing = Container.shared.socialService()

  var body: some View {
    Group {
      if let unlocks {
        if unlocks.isEmpty {
          EmptyStateView(
            icon: "trophy",
            title: String(localized: "No achievements yet"),
            message: String(localized: "Nothing to show here yet.")
          )
        } else {
          List(unlocks) { unlock in
            HStack(spacing: AppTheme.Spacing.md) {
              Image(systemName: AchievementSymbol.name(for: unlock.iconKey))
                .foregroundStyle(AchievementTierStyle.color(unlock.tier))
                .frame(width: 32)
                .accessibilityHidden(true)
              VStack(alignment: .leading, spacing: 2) {
                Text(unlock.title).font(.subheadline.weight(.semibold))
                HStack(spacing: AppTheme.Spacing.xs) {
                  if let label = AchievementTierStyle.label(unlock.tier) {
                    Text(label)
                  }
                  Text(unlock.unlockedAt, style: .date)
                }
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
              }
            }
          }
        }
      } else if let error {
        ErrorRetryView(message: error) { Task { await load() } }
      } else {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .navigationTitle("Achievements")
    .navigationBarTitleDisplayMode(.inline)
    .task { await load() }
  }

  private func load() async {
    do {
      unlocks = try await service.friendAchievements(userId: user.id)
      error = nil
    } catch let failure as SocialHTTPClient.Error where failure.isNotFound {
      error = String(localized: "\(user.title) doesn't share achievements.")
    } catch {
      self.error = error.localizedDescription
    }
  }
}
