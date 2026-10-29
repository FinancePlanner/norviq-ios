import SwiftUI

/// The Feed section of Friends: what friends unlocked lately, with a 🎉.
struct SocialFeedView: View {
  @State private var store = SocialFeedStore()
  @State private var toast: ToastData?

  var body: some View {
    Group {
      if !store.hasLoaded {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if let error = store.loadError, store.items.isEmpty {
        ErrorRetryView(message: error) { Task { await store.refresh() } }
      } else if store.items.isEmpty {
        EmptyStateView(
          icon: "trophy",
          title: String(localized: "No achievements yet"),
          message: String(localized: "When friends unlock achievements, they show up here.")
        )
      } else {
        List {
          ForEach(store.items) { item in
            SocialFeedRow(item: item) { Task { await store.congratulate(item) } }
              .task { await store.loadMoreIfNeeded(after: item) }
          }
          if store.hasMore {
            ProgressView().frame(maxWidth: .infinity)
          }
        }
        .listStyle(.plain)
      }
    }
    .refreshable { await store.refresh() }
    .task {
      if !store.hasLoaded { await store.refresh() }
    }
    .onChange(of: store.actionMessage) { _, message in
      guard let message else { return }
      toast = .error(message)
      store.actionMessage = nil
    }
    .toastOverlay($toast)
  }
}

private struct SocialFeedRow: View {
  let item: SocialFeedItem
  let onCongratulate: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
      SocialAvatar(user: item.actor, size: 40)
      VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
        Text(headline)
          .font(.subheadline)
          .foregroundStyle(AppTheme.Colors.foreground)
        HStack(spacing: AppTheme.Spacing.xs) {
          Image(systemName: AchievementSymbol.name(for: item.achievement.iconKey))
            .foregroundStyle(AchievementTierStyle.color(item.achievement.tier))
            .accessibilityHidden(true)
          Text(item.createdAt, style: .relative)
            .font(.caption)
            .foregroundStyle(AppTheme.Colors.secondaryText)
        }
      }
      Spacer(minLength: 0)
      CongratsButton(cheers: item.congratsCount, isCongratulated: item.viewerCongratulated, action: onCongratulate)
    }
    .padding(.vertical, AppTheme.Spacing.xs)
  }

  private var headline: AttributedString {
    var name = AttributedString(item.actor.title)
    name.font = .subheadline.weight(.semibold)
    var title = AttributedString(item.achievement.title)
    title.font = .subheadline.weight(.semibold)
    let tier: String = switch item.achievement.tier {
    case "gold": String(localized: "Gold")
    case "silver": String(localized: "Silver")
    case "bronze": String(localized: "Bronze")
    default: ""
    }
    var line = name + AttributedString(" " + String(localized: "unlocked") + " ") + title
    if !tier.isEmpty { line += AttributedString(" (\(tier))") }
    return line
  }
}
