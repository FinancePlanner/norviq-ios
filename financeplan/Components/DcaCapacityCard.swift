import Factory
import Observation
import StockPlanShared
import SwiftUI

/// Leftover cash expressed as units of a chosen holding, with the ticker
/// picker. Self-loading; hides itself when the backend has nothing to show.
/// Lives on the dashboard and the portfolio tab — it is an investing surface,
/// not a spending one, so the expenses planner does not carry it.
struct DcaCapacityCard: View {
  @Environment(\.colorScheme) private var scheme
  @State private var viewModel = DcaCapacityViewModel()

  var body: some View {
    Group {
      if let capacity = viewModel.capacity {
        card(capacity)
      }
    }
    .task {
      await viewModel.loadIfNeeded()
    }
  }

  private func card(_ capacity: SpendToUnitsCapacityWire) -> some View {
    GlassCard(cornerRadius: AppTheme.Radius.card) {
      VStack(alignment: .leading, spacing: 10) {
        Text("This month in \(capacity.symbol)")
          .font(.subheadline.weight(.semibold))

        Text(hero(capacity))
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
          TextField("VWCE", text: $viewModel.symbolDraft)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .font(.body.monospaced())
          Button("Set") {
            Task { await viewModel.saveSymbol() }
          }
          .buttonStyle(.borderedProminent)
          .tint(AppTheme.Colors.tint(for: scheme))
        }

        Text(capacity.disclaimer)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func hero(_ capacity: SpendToUnitsCapacityWire) -> String {
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
}

@MainActor
@Observable
final class DcaCapacityViewModel {
  private(set) var capacity: SpendToUnitsCapacityWire?
  var symbolDraft = ""
  private var hasLoaded = false

  private let service: any ExpensesServicing

  init(service: any ExpensesServicing = Container.shared.expensesService()) {
    self.service = service
  }

  func loadIfNeeded() async {
    guard !hasLoaded else { return }
    hasLoaded = true
    guard let loaded = try? await service.getDcaCapacity() else { return }
    capacity = loaded
    symbolDraft = loaded.symbol
  }

  func saveSymbol() async {
    let symbol = symbolDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !symbol.isEmpty else { return }
    guard let updated = try? await service.updateDcaCapacity(symbol: symbol) else { return }
    capacity = updated
    symbolDraft = updated.symbol
  }
}
