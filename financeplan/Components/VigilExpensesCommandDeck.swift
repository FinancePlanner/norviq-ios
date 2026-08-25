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
    VStack(spacing: 12) {
      activityPanel
      dcaPanel
      taxPanel
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
        Text("This month in \(driftViewModel.capacity?.symbol ?? "your ticker")")
          .font(.subheadline.weight(.semibold))
        if let capacity = driftViewModel.capacity {
          Text(capacityHero(capacity))
            .font(.title3.weight(.bold).monospacedDigit())
            .foregroundStyle(AppTheme.Colors.successText(for: scheme))
          if let price = capacity.price {
            Text("at last \(capacity.priceCurrency ?? capacity.currencyCode) \(price.formatted(.number.precision(.fractionLength(2))))")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          ForEach(capacity.categories.prefix(3)) { row in
            Text("\(row.title) · \(overspendLine(row, symbol: capacity.symbol, currency: capacity.currencyCode))")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          HStack {
            TextField("VWCE", text: Bindable(driftViewModel).dcaSymbolDraft)
              .textInputAutocapitalization(.characters)
              .autocorrectionDisabled()
              .font(.body.monospaced())
            Button("Set") {
              Task { await driftViewModel.saveDcaSymbol() }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.tint(for: scheme))
          }
          Text(capacity.disclaimer)
            .font(.caption2)
            .foregroundStyle(.secondary)
          Button("Review reallocation", action: onOpenReallocation)
            .buttonStyle(.bordered)
            .tint(AppTheme.Colors.tint(for: scheme))
        } else if let dashboard = driftViewModel.dashboard {
          let surplus = max(dashboard.investmentContributionTarget - dashboard.lostInvestmentCapital, 0)
          Text("+\(surplus.formatted(.currency(code: currencyCode))) leftover")
            .font(.title3.weight(.bold).monospacedDigit())
            .foregroundStyle(AppTheme.Colors.successText(for: scheme))
        } else {
          Text("Set salary and pillar targets to calculate leftover cash as units of a holding.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private func capacityHero(_ capacity: SpendToUnitsCapacityWire) -> String {
    let cash = capacity.surplusAmount.formatted(.currency(code: capacity.currencyCode))
    if let units = capacity.surplusUnits {
      return "\(cash) → \(units.formatted(.number.precision(.fractionLength(2)))) \(capacity.symbol)"
    }
    return "\(cash) leftover"
  }

  private func overspendLine(_ row: SpendToUnitsCategoryWire, symbol: String, currency: String) -> String {
    let cash = row.overspendAmount.formatted(.currency(code: currency))
    if let units = row.units {
      return "\(cash) → \(units.formatted(.number.precision(.fractionLength(2)))) \(symbol) not bought"
    }
    return "\(cash) over plan"
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
