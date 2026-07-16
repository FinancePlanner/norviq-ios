import Factory
import StockPlanShared
import SwiftUI

struct GoalPlanningDashboardCard: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var overview: GoalOverview?
  @State private var isLoading = true
  private let service: any GoalPlanningServicing = Container.shared.goalPlanningService()
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        progressRing
        VStack(alignment: .leading, spacing: 5) {
          Text("Financial goals")
            .font(.headline)
          Text(summary)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
          if let drift = overview?.items.first?.progress.driftState {
            Label(driftLabel(drift), systemImage: driftSymbol(drift))
              .font(.caption.weight(.semibold))
              .foregroundStyle(driftColor(drift))
          }
        }
        Spacer()
        Image(systemName: "chevron.right")
          .foregroundStyle(.tertiary)
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppTheme.Colors.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Open financial goals. \(summary)")
    .task { await load() }
  }

  private var progressRing: some View {
    ZStack {
      Circle().stroke(.secondary.opacity(0.18), lineWidth: 8)
      Circle()
        .trim(from: 0, to: overview?.items.first?.progress.percentComplete ?? 0)
        .stroke(AppTheme.Colors.tint(for: colorScheme), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        .rotationEffect(.degrees(-90))
      Image(systemName: "target")
        .font(.title3.weight(.semibold))
        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
    }
    .frame(width: 58, height: 58)
    .redacted(reason: isLoading ? .placeholder : [])
  }

  private var summary: String {
    guard !isLoading else { return "Checking your plan…" }
    guard let overview, let first = overview.items.first else { return "Create a plan for what matters next." }
    let percent = first.progress.percentComplete.formatted(.percent.precision(.fractionLength(0)))
    return "\(first.goal.name) is \(percent) funded."
  }

  private func load() async {
    defer { isLoading = false }
    overview = try? await service.overview()
  }

  private func driftLabel(_ drift: GoalDriftState) -> String {
    switch drift {
    case .ahead: "Ahead of plan"
    case .onTrack: "On track"
    case .behind: "Behind plan"
    case .complete: "Goal complete"
    case .insufficientData: "Building a baseline"
    }
  }

  private func driftSymbol(_ drift: GoalDriftState) -> String {
    switch drift {
    case .ahead, .complete: "arrow.up.right.circle.fill"
    case .onTrack: "checkmark.circle.fill"
    case .behind: "exclamationmark.circle.fill"
    case .insufficientData: "clock.fill"
    }
  }

  private func driftColor(_ drift: GoalDriftState) -> Color {
    switch drift {
    case .ahead, .complete, .onTrack: AppTheme.Colors.success
    case .behind: .orange
    case .insufficientData: .secondary
    }
  }
}
