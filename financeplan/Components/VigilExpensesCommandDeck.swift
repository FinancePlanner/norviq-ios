import SwiftUI
import StockPlanShared

/// Watch II spending command deck — the AI-categorized activity table.
/// DCA capacity and the tax forecaster moved to the dashboard and portfolio
/// tabs; this deck stays personal-spending only.
struct VigilExpensesCommandDeck: View {
  @Environment(\.colorScheme) private var scheme

  /// The selected month's expenses only (`commandDeckActivities`).
  let activities: [BudgetActivity]
  /// The budget's currency; nil prints " —" rather than guessing one.
  let currencyCode: String?

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
              Text(verbatim: Self.dateFormatter.string(from: item.occurredOn))
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
              VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                  .font(.caption.weight(.medium))
                  .lineLimit(1)
                Text(verbatim: Self.tagLabel(for: item.pillar))
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(.secondary)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(AppTheme.Colors.tertiaryFill, in: Capsule())
              }
              Spacer(minLength: 4)
              Text(verbatim: MoneyFormatter.string(item.amount, currencyCode: currencyCode))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppTheme.Colors.dangerText(for: scheme))
            }
          }
        }
      }
    }
  }

  /// A plain word for the kind of spending: no brackets, no code-style
  /// casing, no colour per pillar.
  static func tagLabel(for pillar: BudgetPillar) -> String {
    switch pillar {
    case .fundamentals: String(localized: "Fixed")
    case .fun: String(localized: "Leisure")
    default: String(localized: "Variable")
    }
  }

  /// Built once: a `DateFormatter` per row per render was the old cost.
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = MoneyFormatter.defaultLocale
    formatter.setLocalizedDateFormatFromTemplate("MMMd")
    return formatter
  }()
}
