import Factory
import Foundation

extension Container {
  var achievementsService: Factory<any AchievementsServicing> {
    self { @MainActor in
      DefaultAchievementsService(environmentManager: self.appEnvironment())
    }
  }

  /// One coordinator for the app: the foreground check and the sheet that
  /// celebrates what it finds.
  var achievementUnlockCoordinator: Factory<AchievementUnlockCoordinator> {
    self { @MainActor in
      AchievementUnlockCoordinator(
        service: self.achievementsService(),
        isEnabled: { Container.shared.socialStore().config.achievements },
        onCelebrated: { unlock in
          // A fresh win is the moment the review prompt was built for.
          Task { @MainActor in
            let userID = await Container.shared.authSessionStore().currentUserID
            guard !userID.isEmpty else { return }
            Container.shared.reviewPromptCoordinator()
              .consider(.badgeTierEarned(badgeID: unlock.key, tier: unlock.tier), userID: userID)
          }
        }
      )
    }.singleton
  }
}
