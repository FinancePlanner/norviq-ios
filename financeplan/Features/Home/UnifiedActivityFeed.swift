import StockPlanShared
import SwiftUI

enum FinancialHealthCardTone: Equatable {
  case success
  case warning
  case critical
  case neutral
}

struct FinancialHealthCardState: Equatable {
  let scoreText: String
  let summaryText: String
  let tone: FinancialHealthCardTone
  let ringProgress: Double

  init(
    health: DashboardFinancialHealthDTO?,
    isLoading: Bool,
    isUnavailable: Bool
  ) {
    if isLoading {
      self.scoreText = "--"
      self.summaryText = "--/100"
      self.tone = .neutral
      self.ringProgress = 0
      return
    }

    if isUnavailable || health == nil {
      self.scoreText = "--"
      self.summaryText = "--/100 - Unavailable"
      self.tone = .neutral
      self.ringProgress = 0
      return
    }

    guard let health else {
      self.scoreText = "--"
      self.summaryText = "--/100 - Unavailable"
      self.tone = .neutral
      self.ringProgress = 0
      return
    }

    self.scoreText = "\(health.score)"
    self.summaryText = "\(health.score)/\(health.maxScore) - \(Self.statusTitle(health.status))"
    self.ringProgress = health.maxScore > 0
      ? min(max(Double(health.score) / Double(health.maxScore), 0), 1)
      : 0

    switch health.status {
    case .healthy, .excellent:
      self.tone = .success
    case .needsAttention:
      self.tone = .warning
    case .atRisk:
      self.tone = .critical
    }
  }

  private static func statusTitle(_ status: FinancialHealthStatus) -> String {
    switch status {
    case .atRisk:
      "At Risk"
    case .needsAttention:
      "Needs Attention"
    case .healthy:
      "Healthy"
    case .excellent:
      "Excellent"
    }
  }
}

struct UnifiedActivityFeed: View {
  let viewModel: ActivityViewModel
  let recentExpenses: [BudgetActivity]
  let financialHealth: DashboardFinancialHealthDTO?
  let isFinancialHealthLoading: Bool
  let financialHealthUnavailable: Bool

  private var financialHealthCardState: FinancialHealthCardState {
    FinancialHealthCardState(
      health: financialHealth,
      isLoading: isFinancialHealthLoading,
      isUnavailable: financialHealthUnavailable
    )
  }

  private var healthTint: Color {
    switch financialHealthCardState.tone {
    case .success:
      .green
    case .warning:
      .orange
    case .critical:
      .red
    case .neutral:
      .secondary
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Activity Feed")
        .font(.title2.bold())
        .padding(.horizontal, 4)

      GlassCard(cornerRadius: 22) {
        VStack(spacing: 0) {
          if viewModel.isLoading && viewModel.activities.isEmpty {
            ProgressView()
              .padding()
              .frame(maxWidth: .infinity, minHeight: 160)
          } else if viewModel.activities.isEmpty {
            Text("No recent activity")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .padding()
              .frame(maxWidth: .infinity, minHeight: 160)
          } else {
            ForEach(viewModel.activities) { activity in
              HStack(spacing: 16) {
                Circle()
                  .fill(activity.isGrowth ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                  .frame(width: 44, height: 44)
                  .overlay(
                    Image(systemName: activity.symbol)
                      .foregroundStyle(activity.isGrowth ? .green : .red)
                      .font(.title3)
                  )

                VStack(alignment: .leading, spacing: 4) {
                  Text(activity.title)
                    .font(.headline)
                  Text(activity.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                  if let amount = activity.amount {
                    Text(amount > 0 ? "+\(amount.currency)" : "-\(abs(amount).currency)")
                      .font(.headline)
                      .foregroundStyle(activity.isGrowth ? .green : .red)
                  }
                  Text(activity.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .padding(.vertical, 12)

              if activity.id != viewModel.activities.last?.id {
                Divider()
                  .padding(.leading, 60)
              }
            }
          }
        }
      }

      if !recentExpenses.isEmpty {
        GlassCard(cornerRadius: 22) {
          VStack(alignment: .leading, spacing: 12) {
            Text("Recent spend")
              .font(.headline)

            ForEach(recentExpenses.prefix(3)) { activity in
              HStack(spacing: 10) {
                Image(systemName: activity.pillar.symbol)
                  .foregroundStyle(activity.pillar.color(for: .dark))
                VStack(alignment: .leading, spacing: 2) {
                  Text(activity.title)
                    .font(.subheadline.weight(.semibold))
                  Text(activity.occurredOn.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text("-\(activity.amount.currency)")
                  .font(.subheadline.weight(.semibold))
              }
              if activity.id != recentExpenses.prefix(3).last?.id {
                Divider()
              }
            }
          }
        }
      }

      GlassCard(cornerRadius: 22) {
        HStack(spacing: 16) {
          ZStack {
            Circle()
              .stroke(Color.gray.opacity(0.2), lineWidth: 6)
            Circle()
              .trim(from: 0, to: financialHealthCardState.ringProgress)
              .stroke(healthTint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
              .rotationEffect(.degrees(-90))
              .animation(.easeInOut(duration: 0.35), value: financialHealthCardState.ringProgress)
            Text(financialHealthCardState.scoreText)
              .font(.headline)
          }
          .frame(width: 50, height: 50)

          VStack(alignment: .leading, spacing: 4) {
            Text(financialHealthCardState.summaryText)
              .font(.headline)
              .foregroundStyle(healthTint)
            Text("Financial Health")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          Spacer()
        }
        .padding(.vertical, 4)
      }
      .frame(maxWidth: .infinity, minHeight: 112)
      .redacted(reason: isFinancialHealthLoading ? .placeholder : [])
      .scaleEffect(isFinancialHealthLoading ? 0.99 : 1)
      .opacity(isFinancialHealthLoading ? 0.9 : 1)
      .animation(.easeOut(duration: 0.25), value: isFinancialHealthLoading)
    }
  }
}
