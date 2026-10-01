import Factory
import SwiftUI

/// XP level and the daily check-in on the dashboard. Hidden unless the social
/// layer and leaderboards are switched on server-side.
struct GamificationDashboardCard: View {
  @InjectedObservable(\Container.socialStore) private var socialStore
  @InjectedObservable(\Container.gamificationStore) private var store
  @Environment(\.colorScheme) private var scheme

  private var isEnabled: Bool {
    socialStore.config.enabled && socialStore.config.leaderboards
  }

  var body: some View {
    Group {
      if isEnabled {
        card
      }
    }
    .task(id: isEnabled) {
      guard isEnabled else { return }
      await store.load()
      await store.reportBudgetStreakIfNeeded()
    }
  }

  private var card: some View {
    GlassCard(cornerRadius: AppTheme.Radius.card) {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Label("Level \(store.xp?.level ?? 1)", systemImage: "sparkles")
            .font(.subheadline.weight(.semibold))
          Spacer()
          NavigationLink {
            XPHistoryView()
          } label: {
            HStack(spacing: 4) {
              Text("\(store.xp?.total ?? 0) XP")
                .font(.subheadline.weight(.semibold).monospacedDigit())
              Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
            }
          }
          .buttonStyle(.plain)
          .accessibilityHint(Text("Shows how you earned your XP"))
        }

        ProgressView(value: min(max(store.xp?.levelProgress ?? 0, 0), 1))
          .tint(AppTheme.Colors.tint(for: scheme))
          .accessibilityLabel(Text("Progress to the next level"))

        HStack(alignment: .center, spacing: 12) {
          VStack(alignment: .leading, spacing: 2) {
            Label("\(store.streaks?.checkInCurrent ?? 0)-day streak", systemImage: "flame")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.orange)
            Text(statusLine)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Button {
            Task { await store.checkIn() }
          } label: {
            if store.isCheckingIn {
              ProgressView()
            } else if store.hasCheckedInToday {
              Label("Checked in", systemImage: "checkmark")
            } else {
              Text("Check in")
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(AppTheme.Colors.tint(for: scheme))
          .disabled(store.hasCheckedInToday || store.isCheckingIn)
        }
      }
    }
  }

  private var statusLine: String {
    if let checkIn = store.lastCheckIn {
      if checkIn.alreadyCheckedIn {
        return String(localized: "Already checked in today")
      }
      return String(localized: "+\(checkIn.xpAwarded) XP for today's check-in")
    }
    if let week = store.xp?.weekXP, week > 0 {
      return String(localized: "\(week) XP earned this week")
    }
    return String(localized: "Check in daily to grow your streak")
  }
}
