import StockPlanShared
import SwiftUI

struct TaxMarketAdmissionSheet: View {
  @Environment(\.dismiss) private var dismiss
  let service: TaxServiceProtocol
  let onChange: () -> Void
  @State private var instruments: [TaxInstrumentMarketOption]
  @State private var savingID: String?
  @State private var errorMessage: String?

  init(
    service: TaxServiceProtocol,
    instruments: [TaxInstrumentMarketOption],
    onChange: @escaping () -> Void
  ) {
    self.service = service
    self.onChange = onChange
    _instruments = State(initialValue: instruments)
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          Text("Listed securities use Spain's two-month homogeneous-security window. Unlisted securities use one year. Keep the status unknown until the listing is verified.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Section("Investment instruments") {
          if instruments.isEmpty {
            ContentUnavailableView("No instruments", systemImage: "building.columns", description: Text("Sync a brokerage account before classifying markets."))
          }
          ForEach(instruments) { instrument in
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                VStack(alignment: .leading, spacing: 2) {
                  Text(instrument.symbol).font(.headline)
                  Text("Primary listing: \(instrument.listingExchange ?? "Unavailable")")
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if savingID == instrument.id { ProgressView().controlSize(.small) }
              }
              Picker("Market admission", selection: statusBinding(for: instrument)) {
                Text("Unknown").tag(TaxMarketAdmissionStatus.unknown)
                Text("Listed / regulated").tag(TaxMarketAdmissionStatus.regulated)
                Text("Unlisted").tag(TaxMarketAdmissionStatus.unlisted)
              }
              .pickerStyle(.menu)
              .disabled(savingID != nil)
            }
            .padding(.vertical, 4)
          }
        }
        if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red) } }
      }
      .navigationTitle("Market admission")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }

  private func statusBinding(for instrument: TaxInstrumentMarketOption) -> Binding<TaxMarketAdmissionStatus> {
    Binding(
      get: { instruments.first(where: { $0.id == instrument.id })?.marketAdmissionStatus ?? .unknown },
      set: { status in Task { await save(instrument: instrument, status: status) } }
    )
  }

  @MainActor
  private func save(instrument: TaxInstrumentMarketOption, status: TaxMarketAdmissionStatus) async {
    savingID = instrument.id
    errorMessage = nil
    defer { savingID = nil }
    do {
      let updated = try await service.saveMarketAdmission(instrumentId: instrument.id, status: status)
      if let index = instruments.firstIndex(where: { $0.id == updated.id }) { instruments[index] = updated }
      onChange()
    } catch { errorMessage = "The market classification could not be saved." }
  }
}
