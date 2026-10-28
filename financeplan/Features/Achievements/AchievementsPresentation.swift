import SwiftUI

/// Everything the Home screen hangs off for achievements: the unlock
/// celebration, the Achievements sheet it and pushes lead to, and keeping
/// the celebration away from other sheets.
struct AchievementsPresentation: ViewModifier {
  let coordinator: AchievementUnlockCoordinator
  @Binding var isAchievementsPresented: Bool
  /// Another of Home's sheets is up.
  let isCovered: Bool
  let isEnabled: Bool

  @State private var openAchievementsAfterCelebration = false

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: celebrationBinding, onDismiss: openAchievementsIfRequested) {
        AchievementUnlockSheet(
          unlocks: coordinator.pending,
          onViewAll: {
            openAchievementsAfterCelebration = true
            coordinator.dismiss()
          },
          onDone: { coordinator.dismiss() }
        )
      }
      .sheet(isPresented: $isAchievementsPresented) {
        NavigationStack {
          AchievementsView()
            .toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button("Done") { isAchievementsPresented = false }
              }
            }
        }
      }
      .onChange(of: isCovered || isAchievementsPresented, initial: true) { _, covered in
        coordinator.setContextEligible(!covered)
      }
      .onReceive(NotificationCenter.default.publisher(for: .openAchievementsFromPushNotification)) { _ in
        guard isEnabled else { return }
        isAchievementsPresented = true
      }
  }

  private var celebrationBinding: Binding<Bool> {
    Binding(
      get: { coordinator.isPresented },
      set: { isPresented in if !isPresented { coordinator.dismiss() } }
    )
  }

  private func openAchievementsIfRequested() {
    guard openAchievementsAfterCelebration else { return }
    openAchievementsAfterCelebration = false
    isAchievementsPresented = true
  }
}
