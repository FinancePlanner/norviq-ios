import StockPlanShared
import SwiftUI

struct TaxFundClassificationSheet: View {
  @Environment(\.dismiss) private var dismiss
  let service: TaxServiceProtocol
  let instruments: [TaxInstrumentMarketOption]
  let onSaved: () -> Void
  @State private var selections: [String: TaxFundClassification]
  @State private var savingID: String?
  @State private var errorMessage: String?

  init(
    service: TaxServiceProtocol,
    instruments: [TaxInstrumentMarketOption],
    onSaved: @escaping () -> Void
  ) {
    self.service = service
    self.instruments = instruments
    self.onSaved = onSaved
    _selections = State(initialValue: Dictionary(uniqueKeysWithValues: instruments.map {
      ($0.id, $0.fundClassification ?? .unknown)
    }))
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          Text("Use the classification stated in the fund's legal or tax documentation. Stocks do not need classification.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        ForEach(instruments) { instrument in
          Section(instrument.symbol) {
            Picker("Fund category", selection: selection(for: instrument.id)) {
              ForEach(TaxFundClassification.allCases, id: \.self) { classification in
                Text(classification.label).tag(classification)
              }
            }
            Button("Save classification") {
              Task { await save(instrument) }
            }
            .disabled(savingID != nil)
          }
        }
      }
      .navigationTitle("German funds")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
      .overlay { if savingID != nil { ProgressView() } }
      .alert("Could not save classification", isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "") }
    }
  }

  private func selection(for id: String) -> Binding<TaxFundClassification> {
    Binding(get: { selections[id] ?? .unknown }, set: { selections[id] = $0 })
  }

  private func save(_ instrument: TaxInstrumentMarketOption) async {
    savingID = instrument.id
    defer { savingID = nil }
    do {
      _ = try await service.saveFundClassification(
        instrumentId: instrument.id,
        classification: selections[instrument.id] ?? .unknown
      )
      onSaved()
    } catch {
      errorMessage = "Verify the fund category and try again."
    }
  }
}

private extension TaxFundClassification {
  var label: String {
    switch self {
    case .equity: "Equity fund · 30% exempt"
    case .mixed: "Mixed fund · 15% exempt"
    case .realEstate: "Real-estate fund · 60% exempt"
    case .foreignRealEstate: "Foreign real-estate fund · 80% exempt"
    case .other: "Other fund · no exemption"
    case .unknown: "Unknown · professional review"
    }
  }
}
