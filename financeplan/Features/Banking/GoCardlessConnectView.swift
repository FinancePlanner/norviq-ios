import StockPlanShared
import SwiftUI

/// EU bank connection via GoCardless: pick a country, choose a bank, then
/// complete consent in a hosted web flow. The backend creates the connection on
/// its callback, so success just dismisses back to the bank list.
@MainActor
struct GoCardlessConnectView: View {
  let viewModel: BankViewModel

  @Environment(\.dismiss) private var dismiss
  @State private var country = "GB"

  private static let countries: [(code: String, name: String)] = [
    ("GB", "United Kingdom"),
    ("IE", "Ireland"),
    ("PT", "Portugal"),
    ("ES", "Spain"),
    ("FR", "France"),
    ("DE", "Germany"),
    ("NL", "Netherlands"),
    ("IT", "Italy"),
  ]

  var body: some View {
    NavigationStack {
      List {
        Section("Country") {
          Picker("Country", selection: $country) {
            ForEach(Self.countries, id: \.code) { entry in
              Text(entry.name).tag(entry.code)
            }
          }
        }

        Section("Bank") {
          if viewModel.isLoadingInstitutions {
            ProgressView("Loading banks…")
          } else if viewModel.institutions.isEmpty {
            Text("No banks found for this country.")
              .foregroundStyle(.secondary)
          } else {
            ForEach(viewModel.institutions) { institution in
              Button {
                Task {
                  await viewModel.connectGoCardless(institutionId: institution.id)
                  dismiss()
                }
              } label: {
                HStack {
                  Text(institution.name)
                  Spacer()
                  if viewModel.isConnecting {
                    ProgressView()
                  }
                }
              }
              .disabled(viewModel.isConnecting)
            }
          }
        }
      }
      .navigationTitle("Connect EU Bank")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .task(id: country) { await viewModel.loadInstitutions(country: country) }
    }
  }
}
