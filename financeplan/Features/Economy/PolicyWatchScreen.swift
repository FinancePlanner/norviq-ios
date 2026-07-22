import Factory
import Observation
import StockPlanShared
import SwiftUI

@MainActor
@Observable
final class PolicyWatchViewModel {
  var response: PolicyWatchResponse?
  var isLoading = false
  var errorMessage: String?

  private let macroService: any MacroServicing = Container.shared.macroService()

  func load(country: String) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      response = try await macroService.getPolicyWatch(country: country)
    } catch {
      errorMessage = error.localizedDescription
      response = nil
    }
  }
}

struct PolicyWatchScreen: View {
  @State private var viewModel = PolicyWatchViewModel()
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
          ProgressView("Loading policy watch…")
            .frame(maxWidth: .infinity)
            .padding()
        } else if let error = viewModel.errorMessage {
          ContentUnavailableView(
            "Couldn't load policy watch",
            systemImage: "building.columns",
            description: Text(error)
          )
        }
      }
      .padding()
    }
    .refreshable {
      await viewModel.load(country: selectedCountry)
    }
    .navigationTitle("Policy Watch")
    .task {
      if viewModel.response == nil {
        await viewModel.load(country: selectedCountry)
      }
    }
  }

  @ViewBuilder
  private func content(for response: PolicyWatchResponse) -> some View {
    EconomyMaterialCard {
      HStack {
        Label(response.institution, systemImage: "building.columns")
          .font(.headline)
        Spacer()
        if let stance = response.stance {
          stanceBadge(stance)
        }
      }

      Text("Inflation vs \(String(format: "%.1f", response.inflationTarget))% target")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      EconomyIndicatorRow(indicator: response.inflationGauge)

      Text(
        "Distance to target: \(response.distanceToTarget > 0 ? "+" : "")\(String(format: "%.2f", response.distanceToTarget))pp"
      )
      .font(.caption)
      .foregroundStyle(response.distanceToTarget > 0 ? .red : .green)

      if let notes = response.notes {
        Text(notes)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      EconomyMetaFooter(asOf: response.asOf, source: response.source)
    }

    let optionalIndicators: [MacroIndicatorDTO?] = [
      response.policyRate,
      response.treasury2Y,
      response.treasury10Y,
      response.real10Y,
      response.breakeven10Y,
    ]
    let present = optionalIndicators.compactMap { $0 }

    if !present.isEmpty || response.spread10Y2Y != nil {
      EconomyMaterialCard {
        Text("Rates & yields")
          .font(.headline)

        ForEach(Array(present.enumerated()), id: \.offset) { index, indicator in
          EconomyIndicatorRow(indicator: indicator)
          if index < present.count - 1 || response.spread10Y2Y != nil {
            Divider()
          }
        }

        if let spread = response.spread10Y2Y {
          HStack {
            Text("10Y–2Y spread")
              .font(.callout)
            Spacer()
            Text("\(spread > 0 ? "+" : "")\(String(format: "%.2f", spread))pp")
              .font(.callout.weight(.semibold).monospacedDigit())
              .foregroundStyle(spread < 0 ? .red : .primary)
          }
        }
      }
    }

    // Hide next-meeting block (and odds) when meeting is null.
    if let meeting = response.nextMeeting {
      EconomyMaterialCard {
        Text("Next meeting")
          .font(.headline)

        Label(
          "\(meeting.startDate) → \(meeting.endDate) • in \(meeting.daysRemaining) day\(meeting.daysRemaining == 1 ? "" : "s")",
          systemImage: "calendar"
        )
        .font(.callout)

        if meeting.hasPressConference == true {
          Label("Press conference expected", systemImage: "mic")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        // Odds omitted when null / empty (no free licensed feed).
        if let odds = meeting.odds, !odds.isEmpty {
          Divider()
          Text("Rate-move odds")
            .font(.subheadline.weight(.semibold))
          ForEach(Array(odds.enumerated()), id: \.offset) { _, odd in
            HStack {
              Text(odd.move)
                .font(.callout)
              Spacer()
              Text(odd.probability, format: .percent.precision(.fractionLength(0)))
                .font(.callout.weight(.semibold).monospacedDigit())
            }
          }
        }
      }
    }
  }

  private func stanceBadge(_ stance: String) -> some View {
    let color: Color = {
      switch stance.lowercased() {
      case "restrictive": return .red
      case "accommodative": return .green
      default: return .orange
      }
    }()

    return Text(stance.capitalized)
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(color.opacity(0.15), in: Capsule())
      .foregroundStyle(color)
  }
}

#Preview {
  NavigationStack {
    PolicyWatchScreen()
  }
}
