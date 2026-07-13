import StockPlanShared
import SwiftUI

struct TaxLossCarryforwardSheet: View {
  @Environment(\.dismiss) private var dismiss
  let service: TaxServiceProtocol
  let jurisdiction: TaxJurisdiction
  let taxYear: Int

  @State private var ledger: TaxLossCarryforwardLedgerResponse?
  @State private var isLoading = true
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      List {
        if let ledger {
          Section {
            VStack(alignment: .leading, spacing: 5) {
              Text("Available for \(ledger.asOfTaxYear)")
                .font(.subheadline).foregroundStyle(.secondary)
              Text(money(ledger.totalAvailable))
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
            }
            .padding(.vertical, 8)
          } footer: {
            Text(ledgerFooter)
          }

          Section("Source years") {
            if ledger.balances.isEmpty {
              ContentUnavailableView("No carried losses", systemImage: "calendar.badge.checkmark")
            }
            ForEach(ledger.balances) { balance in
              DisclosureGroup {
                LabeledContent("Original loss", value: money(balance.originalAmount))
                LabeledContent("Rule version", value: balance.ruleVersion)
                if balance.applications.isEmpty {
                  Text("No amount has been applied in a later tax year.")
                    .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(balance.applications) { application in
                  LabeledContent("Applied in \(application.targetTaxYear)", value: money(application.amount))
                }
              } label: {
                VStack(alignment: .leading, spacing: 3) {
                  HStack {
                    Text(String(balance.sourceTaxYear)).font(.headline)
                    Text(balance.category?.displayName ?? "Tax loss")
                      .font(.caption2.bold())
                      .padding(.horizontal, 7).padding(.vertical, 3)
                      .background(.secondary.opacity(0.12), in: Capsule())
                    if balance.expiresAfterTaxYear < taxYear {
                      Text("Expired").font(.caption2.bold()).foregroundStyle(.red)
                    }
                  }
                  Text("\(money(balance.remainingAmount)) remaining · \(expiryText(balance))")
                    .font(.caption).foregroundStyle(.secondary)
                }
              }
            }
          }
        }
        if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
      }
      .navigationTitle("Carried tax losses")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
      .overlay { if isLoading { ProgressView() } }
      .task { await load() }
      .refreshable { await load() }
    }
  }

  private func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      ledger = try await service.lossCarryforwards(jurisdiction: jurisdiction, taxYear: taxYear)
      errorMessage = nil
    } catch {
      errorMessage = "Carried losses could not be loaded."
    }
  }

  private func money(_ value: TaxMoney) -> String {
    value.amount.formatted(.currency(code: value.currency))
  }

  private var ledgerFooter: String {
    jurisdiction == .germany
      ? "Stock and general capital losses are tracked separately. The estimate includes classified imported disposals only."
      : "Only losses eligible under your aggregation treatment are included. Confirm imported history with a tax professional."
  }

  private func expiryText(_ balance: TaxLossCarryforwardBalanceResponse) -> String {
    balance.expiresAfterTaxYear >= 9999
      ? "no statutory expiry"
      : "expires after \(balance.expiresAfterTaxYear)"
  }
}

private extension TaxLossCarryforwardCategory {
  var displayName: String {
    switch self {
    case .stock: "Stock loss"
    case .generalCapital: "General capital loss"
    case .securities: "Securities loss"
    case .shortTerm: "Short-term loss"
    case .longTerm: "Long-term loss"
    case .unspecified: "Tax loss"
    }
  }
}
