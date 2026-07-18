import StockPlanShared
import SwiftUI

struct TaxOpportunityDetailSheet: View {
  @Environment(\.dismiss) private var dismiss
  let opportunity: TaxOpportunityResponse
  let onSimulate: (TaxReplacementCandidate?) -> Void
  let onDismiss: () -> Void
  @State private var selectedReplacementID: String?
  @State private var isDismissConfirmationPresented = false

  var body: some View {
    NavigationStack {
      List {
        Section("Estimated impact") {
          LabeledContent("Unrealized loss", value: money(opportunity.unrealizedLoss))
          LabeledContent(
            "Current-year tax reduction",
            value: money(opportunity.currentYearTaxReduction ?? opportunity.estimatedTaxBenefit)
          )
          if let costs = opportunity.estimatedTransactionCosts {
            LabeledContent("Estimated transaction costs", value: money(costs))
          }
          if let afterCost = opportunity.estimatedAfterCostBenefit {
            LabeledContent("After-cost benefit", value: money(afterCost))
          }
        }
        if let lots = opportunity.lots {
          Section("Specific lots") {
            ForEach(lots) { lot in
              VStack(alignment: .leading, spacing: 4) {
                Text("Opened \(lot.openedAt)")
                Text(
                  "\(lot.eligibleQuantity.formatted()) shares · \(lot.holdingPeriod.replacingOccurrences(of: "_", with: " "))"
                )
                .font(.caption).foregroundStyle(.secondary)
                Text("Lot ID \(lot.id)").font(.caption2).foregroundStyle(.tertiary)
              }
            }
          }
        }
        if let candidates = opportunity.replacementCandidates, !candidates.isEmpty {
          Section("Advisor-reviewed replacement") {
            ForEach(candidates) { candidate in
              Button { selectedReplacementID = candidate.instrumentId } label: {
                HStack {
                  VStack(alignment: .leading) {
                    Text(candidate.symbol).foregroundStyle(.primary)
                    Text(
                      "Fit score \(candidate.score.formatted(.percent.precision(.fractionLength(0)))) · confidence \(candidate.confidence.formatted(.percent.precision(.fractionLength(0))))"
                    )
                    .font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  Image(systemName: selectedReplacementID == candidate.instrumentId ? "checkmark.circle.fill" : "circle")
                }
              }
            }
          }
        }
        if !opportunity.warnings.isEmpty {
          Section("Review") { ForEach(opportunity.warnings, id: \.self) { Text($0).font(.footnote) } }
        }
        Section {
          Button("Dismiss opportunity", systemImage: "eye.slash", role: .destructive) {
            isDismissConfirmationPresented = true
          }
        } footer: {
          Text("It will resurface automatically if its estimated benefit increases by at least 25%.")
        }
      }
      .navigationTitle(opportunity.symbol)
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
      .safeAreaInset(edge: .bottom) {
        Button("Run before-and-after simulation") {
          let candidate = opportunity.replacementCandidates?.first { $0.instrumentId == selectedReplacementID }
          dismiss()
          onSimulate(candidate)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(requiresReplacement && selectedReplacementID == nil)
        .padding()
      }
      .onAppear { selectedReplacementID = opportunity.replacementCandidates?.first?.instrumentId }
      .confirmationDialog(
        "Dismiss this opportunity?",
        isPresented: $isDismissConfirmationPresented,
        titleVisibility: .visible
      ) {
        Button("Dismiss opportunity", role: .destructive) {
          dismiss()
          onDismiss()
        }
      }
    }
  }

  private var requiresReplacement: Bool {
    opportunity.replacementCandidates?.isEmpty == false
  }

  private func money(_ value: TaxMoney) -> String {
    value.amount.formatted(.currency(code: value.currency))
  }
}
