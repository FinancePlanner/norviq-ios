import SwiftUI

struct OnboardingSolutionScreen: View {
  let onContinue: () -> Void

  private static let rows: [SolutionRow] = [
    SolutionRow(
      icon: "chart.line.uptrend.xyaxis",
      pain: "WATCH I — WEALTH",
      solution: "Every holding, watched.",
      stat: "Portfolio, crypto, chart builder, scenarios, and research — one place, 10-year projections on every position."
    ),
    SolutionRow(
      icon: "creditcard.fill",
      pain: "WATCH II — SPENDING",
      solution: "Every expense, accounted for.",
      stat: "Expenses, budgets, receipt scanning, bank sync, and tax. People who start tracking save $2,000+ a year."
    ),
    SolutionRow(
      icon: "sparkles",
      pain: "WATCH III — INTELLIGENCE",
      solution: "Every signal, heard.",
      stat: "AI assistant, sentiment insights, macro data, news, and MCP integrations. Nothing slips past."
    )
  ]

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 18) {
          VStack(spacing: 10) {
            Text("One guardian. Three watches.")
              .typography(.title, weight: .bold)
              .multilineTextAlignment(.center)

            Text("You told us what's broken. Norviq stands watch over all of it.")
              .typography(.label)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 16)
          }
          .padding(.top, 24)
          .padding(.bottom, 8)

          ForEach(Self.rows) { row in
            SolutionRowCard(row: row)
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
      }

      OnboardingActionBar(primaryTitle: "I'm in", onPrimary: onContinue)
    }
  }
}

private struct SolutionRow: Identifiable {
  let id = UUID()
  let icon: String
  let pain: String
  let solution: String
  let stat: String
}

private struct SolutionRowCard: View {
  let row: SolutionRow
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GlassCard(cornerRadius: 20) {
      HStack(alignment: .top, spacing: 14) {
        ZStack {
          Circle()
            .fill(AppTheme.Colors.tintSoft(for: colorScheme))
            .frame(width: 44, height: 44)
          Image(systemName: row.icon)
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
        }

        VStack(alignment: .leading, spacing: 6) {
          Text(row.pain)
            .typography(.nano, weight: .semibold)
            .tracking(1.2)
            .foregroundStyle(AppTheme.Colors.bronze(for: colorScheme))
          Text(row.solution)
            .typography(.label, weight: .bold)
            .fixedSize(horizontal: false, vertical: true)
          Text(row.stat)
            .typography(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.vertical, 4)
    }
  }
}
