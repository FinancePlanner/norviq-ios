import Factory
import Observation
import StockPlanShared
import SwiftUI

@MainActor
@Observable
final class HousingHubViewModel {
  var response: HousingHubResponse?
  var isLoading = false
  var errorMessage: String?

  private let macroService: any MacroServicing = Container.shared.macroService()

  func load(country: String) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      response = try await macroService.getHousing(country: country)
    } catch {
      errorMessage = error.localizedDescription
      response = nil
    }
  }
}

struct HousingHubScreen: View {
  @State private var viewModel = HousingHubViewModel()
  @State private var selectedCountry = EconomyCountry.us.rawValue

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        EconomyCountryPicker(selection: $selectedCountry)
          .onChange(of: selectedCountry) { _, newValue in
            Task { await viewModel.load(country: newValue) }
          }

        if let response = viewModel.response {
          content(for: response)
        } else if viewModel.isLoading {
          ProgressView("Loading housing data…")
            .frame(maxWidth: .infinity)
            .padding()
        } else if let error = viewModel.errorMessage {
          ContentUnavailableView(
            "Couldn't load housing data",
            systemImage: "house",
            description: Text(error)
          )
        }
      }
      .padding()
    }
    .refreshable {
      await viewModel.load(country: selectedCountry)
    }
    .navigationTitle("Housing")
    .task {
      if viewModel.response == nil {
        await viewModel.load(country: selectedCountry)
      }
    }
  }

  @ViewBuilder
  private func content(for response: HousingHubResponse) -> some View {
    EconomyMaterialCard {
      Text("Housing — \(response.country)")
        .font(.title2.bold())
      EconomyCoverageChips(coverage: response.coverage)
      if let notes = response.notes {
        Text(notes)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      EconomyMetaFooter(asOf: response.asOf, source: response.source, currency: response.currency)
    }

    let gauges: [(String, MacroIndicatorDTO?)] = [
      ("Home prices", response.hpiYoY),
      ("Mortgage rate", response.mortgageRate),
      ("Rent", response.rentYoY),
      ("Housing starts", response.housingStarts),
      ("Months supply", response.monthsSupply),
    ]
    let present = gauges.compactMap { label, indicator -> (String, MacroIndicatorDTO)? in
      guard let indicator else { return nil }
      return (label, indicator)
    }

    if present.isEmpty {
      ContentUnavailableView(
        "Limited coverage",
        systemImage: "chart.bar.xaxis",
        description: Text("No housing gauges available for \(response.country) yet.")
      )
    } else {
      EconomyMaterialCard {
        Text("Gauges")
          .font(.headline)
        ForEach(Array(present.enumerated()), id: \.offset) { index, item in
          EconomyIndicatorRow(indicator: item.1)
          if index < present.count - 1 {
            Divider()
          }
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    HousingHubScreen()
  }
}
