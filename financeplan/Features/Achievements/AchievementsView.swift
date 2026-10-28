import SwiftUI

/// Everything you can earn, grouped by category, with what you have pinned
/// to your profile on top. Replaces the Badges screen while achievements
/// are on.
struct AchievementsView: View {
  @State private var store = AchievementsStore()
  @State private var toast: ToastData?
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    Group {
      if let response = store.response {
        content(response)
      } else if let error = store.loadError {
        ErrorRetryView(message: error) { Task { await store.load() } }
      } else {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
    .navigationTitle("Achievements")
    .navigationBarTitleDisplayMode(.inline)
    .task { await store.load() }
    .onChange(of: store.actionError) { _, message in
      guard let message else { return }
      toast = .error(message)
      store.actionError = nil
    }
    .toastOverlay($toast)
  }

  private func content(_ response: AchievementsResponse) -> some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
        summary(response.summary)

        let pinned = AchievementsStore.showcase(in: response)
        if !pinned.isEmpty {
          section(title: "Showcase", achievements: pinned)
        }

        ForEach(response.categories) { category in
          let items = response.achievements.filter { $0.category == category.key }
          if !items.isEmpty {
            section(title: LocalizedStringKey(category.title), achievements: items)
          }
        }
      }
      .padding(.horizontal, AppTheme.Spacing.lg)
      .padding(.vertical, AppTheme.Spacing.xl)
    }
    .scrollContentBackground(.hidden)
    .refreshable { await store.load() }
  }

  private func summary(_ summary: AchievementSummary) -> some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
      Text("Unlocked \(summary.unlocked) of \(summary.total)")
        .font(.title3.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.foreground)
      if summary.hiddenRemaining > 0 {
        Text("\(summary.hiddenRemaining) hidden achievements left to find")
          .font(.subheadline)
          .foregroundStyle(AppTheme.Colors.secondaryText)
      }
      Text("Long-press an achievement to pin it to your profile.")
        .font(.footnote)
        .foregroundStyle(AppTheme.Colors.tertiaryText)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func section(title: LocalizedStringKey, achievements: [Achievement]) -> some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
      Text(title)
        .font(.headline)
        .foregroundStyle(AppTheme.Colors.foreground)
        .accessibilityAddTraits(.isHeader)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: AppTheme.Spacing.md)], spacing: AppTheme.Spacing.md) {
        ForEach(achievements) { achievement in
          let pinned = store.isPinned(achievement)
          AchievementCard(
            achievement: achievement,
            isPinned: pinned,
            canPin: AchievementsStore.canPin(achievement) && !store.isSavingShowcase
          ) {
            Task {
              if pinned {
                await store.unpin(achievement)
              } else {
                await store.pin(achievement)
              }
            }
          }
        }
      }
    }
  }
}
