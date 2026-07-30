import SwiftUI
import StockPlanShared

/// Watch II spending command deck — activity table, DCA gauge, tax teaser (mirrors web deck).
struct VigilExpensesCommandDeck: View {
  @Environment(\.colorScheme) private var scheme

  let activities: [BudgetActivity]
  let driftViewModel: BudgetDriftViewModel
  let currencyCode: String
  let onOpenTax: () -> Void
  let onOpenReallocation: () -> Void

  var body: some View {
    if BrandTheme.current == .vigil {
      VStack(spacing: 12) {
        activityPanel
        dcaPanel
        taxPanel
      }
    }
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

  private var dcaPanel: some View {
    GlassCard(cornerRadius: AppTheme.Radius.card) {
      VStack(alignment: .leading, spacing: 10) {
        Text("DCA capacity · surplus cashflow")
          .font(.subheadline.weight(.semibold))
        if let dashboard = driftViewModel.dashboard {
          let surplus = max(dashboard.investmentContributionTarget - dashboard.lostInvestmentCapital, 0)
          Text("+\(surplus.formatted(.currency(code: currencyCode))) DCA ready")
            .font(.title3.weight(.bold).monospacedDigit())
            .foregroundStyle(AppTheme.Colors.successText(for: scheme))
          let deployPct = dashboard.investmentContributionTarget > 0
            ? min(surplus / dashboard.investmentContributionTarget, 1)
            : 0
          ProgressView(value: deployPct)
            .tint(AppTheme.Colors.secondaryTint(for: scheme))
          Text("Deployment target · \(dashboard.investmentContributionTarget.formatted(.currency(code: currencyCode)))")
            .font(.caption)
            .foregroundStyle(.secondary)
          Button("Review reallocation", action: onOpenReallocation)
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.tint(for: scheme))
        } else {
          Text("Set salary and pillar targets to calculate deploy capacity.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var taxPanel: some View {
    GlassCard(cornerRadius: AppTheme.Radius.card) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Tax liability forecaster")
          .font(.subheadline.weight(.semibold))
        Text("Jurisdiction-aware estimates from your tax profile.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Button("Open tax strategy", action: onOpenTax)
          .buttonStyle(.bordered)
          .tint(AppTheme.Colors.tint(for: scheme))
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
