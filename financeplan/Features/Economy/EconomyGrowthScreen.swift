import Factory
import Observation
import StockPlanShared
import SwiftUI

@MainActor
@Observable
final class EconomyGrowthViewModel {
  var response: EconomyHubResponse?
  var isLoading = false
  var errorMessage: String?

  private let macroService: any MacroServicing = Container.shared.macroService()

  func load(country: String) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      response = try await macroService.getEconomy(country: country)
    } catch {
      errorMessage = error.localizedDescription
      response = nil
    }
  }
}

struct EconomyGrowthScreen: View {
  @State private var viewModel = EconomyGrowthViewModel()
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
          ProgressView("Loading growth & jobs…")
            .frame(maxWidth: .infinity)
            .padding()
        } else if let error = viewModel.errorMessage {
          ContentUnavailableView(
            "Couldn't load economy data",
            systemImage: "briefcase",
            description: Text(error)
          )
        }
      }
      .padding()
    }
    .refreshable {
      await viewModel.load(country: selectedCountry)
    }
    .navigationTitle("Growth & Jobs")
    .task {
      if viewModel.response == nil {
        await viewModel.load(country: selectedCountry)
      }
    }
  }

  @ViewBuilder
  private func content(for response: EconomyHubResponse) -> some View {
    EconomyMaterialCard {
      HStack(alignment: .firstTextBaseline) {
        Text("Growth & Jobs — \(response.country)")
          .font(.title2.bold())
        Spacer()
        if let risk = response.riskLabel {
          riskBadge(risk)
        }
      }

      EconomyCoverageChips(coverage: response.coverage)

      if let official = response.officialRecession {
        Label(
          official ? "Official recession: active" : "Official recession: not active",
          systemImage: official ? "exclamationmark.triangle.fill" : "checkmark.seal"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(official ? .red : .green)
      }

      if let spread = response.yieldCurveSpread {
        Text("Yield curve (10Y–2Y): \(spread > 0 ? "+" : "")\(String(format: "%.2f", spread))pp")
          .font(.callout)
          .foregroundStyle(spread < 0 ? .red : .secondary)
      }

      if let notes = response.notes {
        Text(notes)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      EconomyMetaFooter(asOf: response.asOf, source: response.source, currency: response.currency)
    }

    let gauges: [MacroIndicatorDTO?] = [
      response.unemployment,
      response.gdpGrowth,
      response.payrolls,
      response.initialClaims,
      response.policyRate,
      response.sahmRule,
    ]
    let present = gauges.compactMap { $0 }

    if present.isEmpty {
      ContentUnavailableView(
        "Limited coverage",
        systemImage: "chart.bar.xaxis",
        description: Text("No growth gauges available for \(response.country) yet.")
      )
    } else {
      EconomyMaterialCard {
        Text("Gauges")
          .font(.headline)
        ForEach(Array(present.enumerated()), id: \.offset) { index, indicator in
          EconomyIndicatorRow(indicator: indicator)
          if index < present.count - 1 {
            Divider()
          }
        }
      }
    }
  }

  private func riskBadge(_ label: String) -> some View {
    let color: Color = {
      switch label.lowercased() {
      case "elevated": return .red
      case "watch": return .orange
      case "low": return .green
      default: return .secondary
      }
    }()

    return Text(label.capitalized)
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(color.opacity(0.15), in: Capsule())
      .foregroundStyle(color)
  }
}

#Preview {
  NavigationStack {
    EconomyGrowthScreen()
  }
}
