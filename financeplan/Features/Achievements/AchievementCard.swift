import SwiftUI

/// One achievement in the grid: icon, copy, tier pills and, while in
/// progress, a bar toward the next tier. Hidden ones show only "???".
struct AchievementCard: View {
  let achievement: Achievement
  let isPinned: Bool
  let canPin: Bool
  let onTogglePin: () -> Void

  @Environment(\.colorScheme) private var scheme

  private var isHidden: Bool { achievement.state == .hidden }
  private var isEarned: Bool { achievement.currentTier != nil }

  var body: some View {
    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
      HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
        icon
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
          Text(isHidden ? "???" : achievement.title)
            .font(.headline)
            .foregroundStyle(isEarned ? AppTheme.Colors.foreground : AppTheme.Colors.secondaryText)
          Text(achievement.description)
            .font(.subheadline)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
        if isPinned {
          Image(systemName: "pin.fill")
            .font(.caption)
            .foregroundStyle(AppTheme.Colors.tint)
            .accessibilityLabel(Text("Pinned"))
        }
      }

      if !isHidden {
        tierPills
      }

      if let progress = achievement.progress, !achievement.isPerformance, !isHidden {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
          ProgressView(value: Double(min(progress.current, progress.target)), total: Double(max(progress.target, 1)))
            .tint(AppTheme.Colors.tint)
          Text("\(progress.current) / \(progress.target)")
            .font(.caption)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .monospacedDigit()
        }
      }
    }
    .padding(AppTheme.Spacing.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppTheme.Colors.cardBackground(for: scheme))
    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    .overlay(
      RoundedRectangle(cornerRadius: AppTheme.Radius.card)
        .stroke(AppTheme.Colors.separator(for: scheme), lineWidth: 1)
    )
    .opacity(isEarned || achievement.state == .inProgress ? 1 : 0.75)
    .contextMenu {
      if isPinned {
        Button("Unpin from profile", systemImage: "pin.slash", action: onTogglePin)
      } else if canPin {
        Button("Pin to profile", systemImage: "pin", action: onTogglePin)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var icon: some View {
    let tint = isEarned ? AchievementTierStyle.color(achievement.currentTier ?? "") : AppTheme.Colors.tertiaryText
    return Image(systemName: isHidden ? "lock.fill" : AchievementSymbol.name(for: achievement.iconKey))
      .font(.title3)
      .foregroundStyle(tint)
      .frame(width: 44, height: 44)
      .background(Circle().fill(tint.opacity(isEarned ? 0.15 : 0.08)))
      .accessibilityHidden(true)
  }

  @ViewBuilder
  private var tierPills: some View {
    let labelled = achievement.tiers.filter { AchievementTierStyle.label($0.tier) != nil }
    if !labelled.isEmpty {
      HStack(spacing: AppTheme.Spacing.xs) {
        ForEach(labelled, id: \.tier) { tier in
          let earned = tier.unlockedAt != nil
          if let label = AchievementTierStyle.label(tier.tier) {
            Text(label)
              .font(.caption.weight(.medium))
              .padding(.horizontal, AppTheme.Spacing.sm)
              .padding(.vertical, 2)
              .foregroundStyle(earned ? AchievementTierStyle.color(tier.tier) : AppTheme.Colors.tertiaryText)
              .background(
                Capsule().fill(earned ? AchievementTierStyle.color(tier.tier).opacity(0.14) : Color.clear)
              )
              .overlay(Capsule().stroke(AppTheme.Colors.separator(for: scheme), lineWidth: earned ? 0 : 1))
              .accessibilityLabel(earned ? Text("\(Text(label)) earned") : Text("\(Text(label)) not yet earned"))
          }
        }
      }
    }
  }
}
