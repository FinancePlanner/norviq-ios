import SwiftUI

struct OnboardingSolutionScreen: View {
  let onContinue: () -> Void

  private static let rows: [SolutionRow] = [
    SolutionRow(
      icon: "rectangle.stack.fill",
      pain: "Investments scattered across apps",
      solution: "All your holdings in one portfolio.",
      stat: "4 in 10 investors juggle two or more investment apps."
    ),
    SolutionRow(
      icon: "magnifyingglass.circle.fill",
      pain: "Mystery spending",
      solution: "Auto-categorised expenses with leak detection.",
      stat: "People who start tracking save $2,000+ a year — money that could be earning compound returns."
    ),
    SolutionRow(
      icon: "chart.line.uptrend.xyaxis",
      pain: "No projection clarity",
      solution: "10-year projections on every position.",
      stat: "What a spreadsheet takes 30 minutes to model, you see in 5 seconds."
    ),
    SolutionRow(
      icon: "scale.3d",
      pain: "Allocation guesswork",
      solution: "Visual allocation across stock, sector, and asset class.",
      stat: "Spot concentration risk before the market does."
    )
  ]

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 18) {
          VStack(spacing: 10) {
            Text("A smarter way to see your money.")
              .typography(.title, weight: .bold)
              .multilineTextAlignment(.center)

            Text("You told us what's broken. Here's how Norviq fixes it.")
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
            .typography(.nano)
            .foregroundStyle(.secondary)
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
