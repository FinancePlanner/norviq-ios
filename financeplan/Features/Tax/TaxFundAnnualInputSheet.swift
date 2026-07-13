import StockPlanShared
import SwiftUI

struct TaxFundAnnualInputSheet: View {
  private struct LotDraft {
    var isIncluded = false
    var quantity = ""
    var beginningValue = ""
    var endingValue = ""
    var distributions = "0"
    var acquisitionMonth = ""
  }

  @Environment(\.dismiss) private var dismiss
  let service: TaxServiceProtocol
  let context: TaxProfileContextResponse?

  @State private var accountID = ""
  @State private var instrumentID = ""
  @State private var calculationYear = 2026
  @State private var beginningValue = ""
  @State private var endingValue = ""
  @State private var distributions = "0"
  @State private var acquisitionMonth = ""
  @State private var lotDrafts: [String: LotDraft] = [:]
  @State private var result: TaxFundAdvanceLumpSumResponse?
  @State private var isSaving = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Account", selection: $accountID) {
            Text("Choose account").tag("")
            ForEach(context?.accounts ?? []) { account in
              Text(account.displayName).tag(account.id)
            }
          }
          Picker("Fund or ETF", selection: $instrumentID) {
            Text("Choose instrument").tag("")
            ForEach(context?.instruments ?? []) { instrument in
              Text(instrument.symbol).tag(instrument.id)
            }
          }
          Picker("Calculation year", selection: $calculationYear) {
            Text("2025").tag(2025)
            Text("2026").tag(2026)
          }
        } header: {
          Text("Annual holding")
        } footer: {
          Text("Use complete values from the fund or broker statement. Imported lots are submitted as separate acquisition tranches.")
        }

        if eligibleLots.isEmpty {
          Section("Values") {
            decimalField("Beginning market value", text: $beginningValue)
            decimalField("Ending market value", text: $endingValue)
            decimalField("Distributions", text: $distributions)
            TextField("Acquisition month (1–12)", text: $acquisitionMonth)
              .keyboardType(.numberPad)
          }
        } else {
          Section {
            ForEach(eligibleLots) { lot in
              VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: includedBinding(for: lot)) {
                  VStack(alignment: .leading, spacing: 3) {
                    Text("Lot opened \(lot.openedAt)")
                    Text("\(quantityText(lot.remainingQuantity)) of \(quantityText(lot.originalQuantity)) remaining")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                }

                if lotDrafts[lot.id]?.isIncluded == true {
                  decimalField("Quantity", text: draftBinding(for: lot.id, \.quantity))
                  decimalField("Beginning market value", text: draftBinding(for: lot.id, \.beginningValue))
                  decimalField("Ending market value", text: draftBinding(for: lot.id, \.endingValue))
                  decimalField("Distributions", text: draftBinding(for: lot.id, \.distributions))
                  TextField("Acquisition month (1–12)", text: draftBinding(for: lot.id, \.acquisitionMonth))
                    .keyboardType(.numberPad)
                }
              }
              .padding(.vertical, 4)
            }
          } header: {
            Text("Tax lots")
          } footer: {
            Text("Select every lot covered by the annual statement. Quantity cannot exceed the remaining imported balance.")
          }
        }

        if let result {
          Section("Calculated advance lump sum") {
            LabeledContent("Basis rate", value: percent(result.basisRate))
            LabeledContent("Gross amount", value: money(result.grossAdvanceLumpSum, currency: result.currency))
            LabeledContent("Taxable after exemption", value: money(result.taxableAdvanceLumpSum, currency: result.currency))
            LabeledContent("Deemed received", value: String(result.deemedReceiptTaxYear))
          }
        }
      }
      .navigationTitle("Annual fund values")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await save() } }.disabled(!canSave || isSaving)
        }
      }
      .overlay { if isSaving { ProgressView() } }
      .alert("Could not save annual values", isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }
  }

  private var canSave: Bool {
    guard !accountID.isEmpty, !instrumentID.isEmpty else { return false }
    if eligibleLots.isEmpty {
      return validValues(
        quantity: nil,
        maximumQuantity: nil,
        beginning: beginningValue,
        ending: endingValue,
        distributions: distributions,
        acquisitionMonth: acquisitionMonth
      )
    }

    let selected = eligibleLots.compactMap { lot -> (TaxFundLotOption, LotDraft)? in
      guard let draft = lotDrafts[lot.id], draft.isIncluded else { return nil }
      return (lot, draft)
    }
    return !selected.isEmpty && selected.allSatisfy { lot, draft in
      validValues(
        quantity: draft.quantity,
        maximumQuantity: lot.remainingQuantity,
        beginning: draft.beginningValue,
        ending: draft.endingValue,
        distributions: draft.distributions,
        acquisitionMonth: draft.acquisitionMonth
      )
    }
  }

  private var eligibleLots: [TaxFundLotOption] {
    (context?.fundLots ?? []).filter {
      $0.accountId == accountID && $0.instrumentId == instrumentID && $0.remainingQuantity > 0
    }
  }

  private func decimalField(_ title: String, text: Binding<String>) -> some View {
    TextField(title, text: text).keyboardType(.decimalPad)
  }

  private func draftBinding(
    for lotID: String,
    _ keyPath: WritableKeyPath<LotDraft, String>
  ) -> Binding<String> {
    Binding(
      get: { lotDrafts[lotID]?[keyPath: keyPath] ?? "" },
      set: { value in
        var draft = lotDrafts[lotID] ?? LotDraft()
        draft[keyPath: keyPath] = value
        lotDrafts[lotID] = draft
      }
    )
  }

  private func includedBinding(for lot: TaxFundLotOption) -> Binding<Bool> {
    Binding(
      get: { lotDrafts[lot.id]?.isIncluded ?? false },
      set: { isIncluded in
        var draft = lotDrafts[lot.id] ?? LotDraft()
        draft.isIncluded = isIncluded
        if isIncluded && draft.quantity.isEmpty {
          draft.quantity = quantityText(lot.remainingQuantity)
        }
        lotDrafts[lot.id] = draft
      }
    )
  }

  private func save() async {
    let holdings: [TaxFundAnnualHoldingInput]
    if eligibleLots.isEmpty {
      guard let beginning = decimal(beginningValue),
            let ending = decimal(endingValue),
            let paidDistributions = decimal(distributions)
      else { return }
      holdings = [.init(
        id: "aggregate",
        beginningMarketValue: beginning,
        endingMarketValue: ending,
        distributions: paidDistributions,
        acquisitionMonth: acquisitionMonth.isEmpty ? nil : Int(acquisitionMonth)
      )]
    } else {
      holdings = eligibleLots.compactMap { lot in
        guard let draft = lotDrafts[lot.id], draft.isIncluded,
              let quantity = decimal(draft.quantity),
              let beginning = decimal(draft.beginningValue),
              let ending = decimal(draft.endingValue),
              let paidDistributions = decimal(draft.distributions)
        else { return nil }
        return .init(
          id: lot.id,
          lotId: lot.id,
          quantity: quantity,
          beginningMarketValue: beginning,
          endingMarketValue: ending,
          distributions: paidDistributions,
          acquisitionMonth: draft.acquisitionMonth.isEmpty ? nil : Int(draft.acquisitionMonth)
        )
      }
    }

    guard !holdings.isEmpty else { return }
    isSaving = true
    defer { isSaving = false }
    do {
      result = try await service.saveFundAnnualInput(.init(
        accountId: accountID,
        instrumentId: instrumentID,
        calculationYear: calculationYear,
        currency: context?.defaultReportingCurrency ?? "EUR",
        holdings: holdings
      ))
      errorMessage = nil
    } catch {
      errorMessage = "Confirm the fund classification and annual statement values, then try again."
    }
  }

  private func decimal(_ value: String) -> Decimal? {
    Decimal(string: value.replacingOccurrences(of: ",", with: "."))
  }

  private func validValues(
    quantity: String?,
    maximumQuantity: Decimal?,
    beginning: String,
    ending: String,
    distributions: String,
    acquisitionMonth: String
  ) -> Bool {
    if let quantity, let maximumQuantity {
      guard let parsedQuantity = decimal(quantity),
            parsedQuantity > 0,
            parsedQuantity <= maximumQuantity
      else { return false }
    }
    return decimal(beginning).map { $0 >= 0 } == true
      && decimal(ending).map { $0 >= 0 } == true
      && decimal(distributions).map { $0 >= 0 } == true
      && (acquisitionMonth.isEmpty || Int(acquisitionMonth).map { (1 ... 12).contains($0) } == true)
  }

  private func quantityText(_ quantity: Decimal) -> String {
    NSDecimalNumber(decimal: quantity).stringValue
  }

  private func money(_ amount: Decimal, currency: String) -> String {
    amount.formatted(.currency(code: currency))
  }

  private func percent(_ value: Decimal) -> String {
    (value * 100).formatted(.number.precision(.fractionLength(2))) + "%"
  }
}
