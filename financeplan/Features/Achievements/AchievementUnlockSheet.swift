import SwiftUI

/// The moment an achievement lands: one unlock gets its icon, tier and XP;
/// several get a count. Static under Reduce Motion.
struct AchievementUnlockSheet: View {
  let unlocks: [AchievementUnlock]
  let onViewAll: () -> Void
  let onDone: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var scheme
  @State private var appeared = false

  private var first: AchievementUnlock? { unlocks.first }
  private var tierColor: Color { AchievementTierStyle.color(first?.tier ?? "") }

  var body: some View {
    VStack(spacing: AppTheme.Spacing.lg) {
      Image(systemName: AchievementSymbol.name(for: first?.iconKey ?? AchievementSymbol.fallback))
        .font(.system(size: 48, weight: .semibold))
        .foregroundStyle(tierColor)
        .frame(width: 96, height: 96)
        .background(Circle().fill(tierColor.opacity(0.15)))
        .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
        .opacity(appeared || reduceMotion ? 1 : 0)
        .accessibilityHidden(true)

      VStack(spacing: AppTheme.Spacing.xs) {
        if unlocks.count > 1 {
          Text("\(unlocks.count) achievements unlocked")
            .font(.title2.weight(.bold))
        } else {
          Text("Achievement unlocked")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        if let first {
          Text(first.title)
            .font(unlocks.count > 1 ? .headline : .title2.weight(.bold))
          if let label = AchievementTierStyle.label(first.tier) {
            Text(label)
              .font(.caption.weight(.semibold))
              .foregroundStyle(tierColor)
          }
          if unlocks.count == 1 {
            Text(first.description)
              .font(.body)
              .foregroundStyle(AppTheme.Colors.secondaryText)
              .multilineTextAlignment(.center)
          }
          if first.xp > 0, unlocks.count == 1 {
            Text("+\(first.xp) XP")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(AppTheme.Colors.tint)
              .monospacedDigit()
          }
        }
      }
      .multilineTextAlignment(.center)
      .foregroundStyle(AppTheme.Colors.foreground)

      VStack(spacing: AppTheme.Spacing.sm) {
        Button(action: onViewAll) {
          Text("View all achievements").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        Button("Done", action: onDone)
          .buttonStyle(.borderless)
      }
    }
    .padding(AppTheme.Spacing.xl)
    .frame(maxWidth: .infinity)
    .background(AppTheme.Colors.pageBackground(for: scheme).ignoresSafeArea())
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .accessibilityElement(children: .contain)
    .sensoryFeedback(.success, trigger: appeared)
    .onAppear {
      if reduceMotion {
        appeared = true
      } else {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { appeared = true }
      }
    }
  }
}
