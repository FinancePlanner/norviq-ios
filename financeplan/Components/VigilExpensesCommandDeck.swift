import SwiftUI
import StockPlanShared

/// Watch II spending command deck — the AI-categorized activity table.
/// DCA capacity and the tax forecaster moved to the dashboard and portfolio
/// tabs; this deck stays personal-spending only.
struct VigilExpensesCommandDeck: View {
  @Environment(\.colorScheme) private var scheme

  let activities: [BudgetActivity]
  let currencyCode: String

  var body: some View {
    activityPanel
  }

  private var activityPanel: some View {
    GlassCard(cornerRadius: AppTheme.Radius.card) {
      VStack(alignment: .leading, spacing: 10) {
        Text("Monthly expenses · AI categorized")
          .font(.subheadline.weight(.semibold))
        if activities.isEmpty {
          Text("No spending logged this month.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(activities.prefix(6)) { item in
            HStack(alignment: .top) {
              Text(item.dateLabel)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
              VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                  .font(.caption.weight(.medium))
                  .lineLimit(1)
                Text(aiTag(for: item.pillar))
                  .font(.caption2.weight(.bold).monospaced())
                  .foregroundStyle(tagColor(for: item.pillar))
              }
              Spacer(minLength: 4)
              Text(item.amount, format: .currency(code: currencyCode))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppTheme.Colors.dangerText(for: scheme))
            }
          }
        }
      }
    }
  }

  private func aiTag(for pillar: BudgetPillar) -> String {
    switch pillar {
    case .fundamentals: "[FIXED: \(pillar.title)]"
    case .fun: "[LEISURE: \(pillar.title)]"
    default: "[VARIABLE: \(pillar.title)]"
    }
  }

  private func tagColor(for pillar: BudgetPillar) -> Color {
    switch pillar {
    case .fundamentals: AppTheme.Colors.tint(for: scheme)
    case .fun: AppTheme.Colors.warningText(for: scheme)
    default: AppTheme.Colors.secondaryTint(for: scheme)
    }
  }
}

private extension BudgetActivity {
  var dateLabel: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter.string(from: occurredOn)
  }
}
