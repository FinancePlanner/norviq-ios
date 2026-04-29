import StockPlanShared
import SwiftUI

@MainActor
struct SellStockSheet: View {
  let stock: StockResponse
  let isSelling: Bool
  let allocationImpactProvider: ((SellStockRequest) -> PortfolioAllocationImpact?)?
  let onCancel: () -> Void
  let onSell: @MainActor (SellStockRequest) async -> String?

  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dismiss) private var dismiss
  @State private var sharesText: String
  @State private var sellPriceText: String
  @State private var sellDateText: String
  @State private var errorMessage: String?
  @State private var successFeedbackTrigger = 0

  init(
    stock: StockResponse,
    isSelling: Bool,
    allocationImpactProvider: ((SellStockRequest) -> PortfolioAllocationImpact?)? = nil,
    onCancel: @escaping () -> Void,
    onSell: @escaping @MainActor (SellStockRequest) async -> String?
  ) {
    self.stock = stock
    self.isSelling = isSelling
    self.allocationImpactProvider = allocationImpactProvider
    self.onCancel = onCancel
    self.onSell = onSell
    _sharesText = State(initialValue: "")
    _sellPriceText = State(initialValue: stock.buyPrice.formatted(.number.precision(.fractionLength(2))))
    _sellDateText = State(initialValue: Self.todayDateString())
  }

  private var parsedShares: Double? {
    Double(sharesText.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  private var parsedSellPrice: Double? {
    Double(sellPriceText.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  private var isSubmitDisabled: Bool {
    isSelling || parsedShares == nil || parsedSellPrice == nil
  }

  var body: some View {
    VStack(spacing: 0) {
      FormSheetHeader(
        title: "Sell Position",
        subtitle: stock.symbol,
        onDismiss: {
          onCancel()
          dismiss()
        }
      )

      ScrollView {
        VStack(spacing: 16) {
          HStack {
            FormInfoTag(text: stock.symbol, icon: "minus.circle")
            Spacer()
          }

          FormCard(title: "Sell details") {
            FormTextField(
              icon: "number",
              placeholder: "Shares to sell",
              text: $sharesText,
              keyboardType: .decimalPad
            )

            FormDivider()

            FormTextField(
              icon: "dollarsign.circle",
              iconColor: AppTheme.Colors.secondaryTint(for: colorScheme),
              placeholder: "Sell price",
              text: $sellPriceText,
              keyboardType: .decimalPad
            )

            FormDivider()

            FormTextField(
              icon: "calendar",
              iconColor: .orange,
              placeholder: "Sell date (YYYY-MM-DD)",
              text: $sellDateText,
              autocapitalization: .never
            )
          }

          GlassCard {
            VStack(alignment: .leading, spacing: 8) {
              Text("Current position")
                .typography(.caption, weight: .semibold)
                .foregroundStyle(.secondary)

              Text("\(stock.shares.formatted(.number.precision(.fractionLength(0...2)))) shares @ \(stock.buyPrice.currency)")
                .typography(.small, weight: .semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }

          if let request = currentRequest, let impact = allocationImpactProvider?(request), impact.didChange {
            AllocationImpactPreviewCard(impact: impact)
          }

          if let errorMessage {
            FormErrorBanner(message: errorMessage)
          }

          Spacer(minLength: 80)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
      }
      .scrollDismissesKeyboard(.interactively)

      FormActionBar(
        primaryLabel: isSelling ? "Selling…" : "Sell",
        isLoading: isSelling,
        isDisabled: isSubmitDisabled
      ) {
        Task { @MainActor in
          await submit()
        }
      }
    }
    .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
    .presentationDragIndicator(.visible)
    .appSensoryFeedback(success: successFeedbackTrigger)
  }

  private func submit() async {
    guard let request = currentRequest else {
      errorMessage = "Enter valid shares and sell price."
      return
    }

    guard request.sharesToSell > 0 else {
      errorMessage = "Shares to sell must be greater than 0."
      return
    }

    guard request.sharesToSell <= stock.shares else {
      errorMessage = "Cannot sell more shares than currently owned."
      return
    }

    guard request.sellPrice > 0 else {
      errorMessage = "Sell price must be greater than 0."
      return
    }

    if let error = await onSell(request) {
      errorMessage = error
      return
    }

    errorMessage = nil
    successFeedbackTrigger += 1
    onCancel()
    dismiss()
  }

  private static func todayDateString() -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
  }

  private var currentRequest: SellStockRequest? {
    guard let sharesToSell = parsedShares, let sellPrice = parsedSellPrice else { return nil }
    return SellStockRequest(
      sharesToSell: sharesToSell,
      sellPrice: sellPrice,
      sellDate: sellDateText.trimmingCharacters(in: .whitespacesAndNewlines)
    )
  }
}
