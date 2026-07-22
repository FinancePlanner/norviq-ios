import StockPlanShared
import SwiftUI

struct PersonalInflationScreen: View {
  @State private var viewModel = PersonalInflationViewModel()
  @State private var selectedCountry = "US"
  @State private var selectedMonths = 12

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        controls

        if let response = viewModel.response {
          PersonalInflationHero(response: response)
          PersonalInflationCoverage(response: response)
          PersonalInflationComponents(response: response)
          Text("Calculated from your recorded expenses. Savings, investments, and categories without a matching official inflation component are excluded from the rate.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if viewModel.isLoading {
          ProgressView("Calculating your inflation…")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if let errorMessage = viewModel.errorMessage {
          ContentUnavailableView(
            "Couldn't calculate your inflation",
            systemImage: "exclamationmark.triangle",
            description: Text(errorMessage)
          )
        }
      }
      .padding()
    }
    .navigationTitle("Your Inflation")
    .refreshable { await reload() }
    .task { await reload() }
  }

  private var controls: some View {
    VStack(spacing: 12) {
      Picker("Country", selection: $selectedCountry) {
        Text("🇺🇸 US").tag("US")
        Text("🇧🇷 Brazil").tag("BR")
        Text("🇵🇹 Portugal").tag("PT")
        Text("🇪🇺 Euro Area").tag("EA")
      }
      .pickerStyle(.segmented)

      Picker("Expense history", selection: $selectedMonths) {
        Text("6 months").tag(6)
        Text("12 months").tag(12)
        Text("24 months").tag(24)
      }
      .pickerStyle(.segmented)
    }
    .onChange(of: selectedCountry) { _, _ in Task { await reload() } }
    .onChange(of: selectedMonths) { _, _ in Task { await reload() } }
  }

  private func reload() async {
    await viewModel.load(country: selectedCountry, months: selectedMonths)
  }
}

private struct PersonalInflationHero: View {
  let response: PersonalInflationResponse

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("YOUR SPENDING-WEIGHTED RATE")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .tracking(1.1)

      if let rate = response.personalRate {
        Text(rate, format: .number.precision(.fractionLength(2)))
          .font(.system(size: 50, weight: .bold, design: .rounded))
          .foregroundStyle(.tint)
          .contentTransition(.numericText(value: rate))
          .overlay(alignment: .trailing) {
            Text("%")
              .font(.title.bold())
              .offset(x: 28)
          }
          .padding(.trailing, 28)
        if let comparison = PersonalInflationViewModel.comparisonText(for: response) {
          Text(comparison)
            .font(.subheadline.weight(.medium))
        }
      } else {
        Text("Not enough mapped spending yet")
          .font(.title2.bold())
        Text("Record groceries, housing, utilities, transport, or other everyday expenses to build your rate.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      HStack {
        LabeledContent("Official", value: response.officialRate.formatted(.number.precision(.fractionLength(2))) + "%")
        Spacer()
        LabeledContent("Period", value: "\(response.periodMonths) mo")
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      if let impact = response.estimatedAnnualImpact {
        Divider()
        LabeledContent(
          "Estimated annual price impact",
          value: impact.formatted(.currency(code: response.currency).precision(.fractionLength(0)))
        )
        .font(.subheadline.weight(.semibold))
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    .accessibilityElement(children: .combine)
  }
}

private struct PersonalInflationCoverage: View {
  let response: PersonalInflationResponse

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Expense coverage")
          .font(.headline)
        Spacer()
        Text(response.coveragePercent / 100, format: .percent.precision(.fractionLength(0)))
          .font(.headline.monospacedDigit())
      }
      ProgressView(value: response.coveragePercent, total: 100)
        .tint(response.coveragePercent >= 70 ? .green : .orange)
      Text("\(response.expenseCount) expenses · \(response.mappedSpend.formatted(.currency(code: response.currency).precision(.fractionLength(0)))) of \(response.totalSpend.formatted(.currency(code: response.currency).precision(.fractionLength(0)))) mapped")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    .accessibilityElement(children: .combine)
  }
}

private struct PersonalInflationComponents: View {
  let response: PersonalInflationResponse

  var body: some View {
    if !response.components.isEmpty {
      VStack(alignment: .leading, spacing: 14) {
        Text("What drives your rate")
          .font(.headline)
        ForEach(response.components) { component in
          VStack(alignment: .leading, spacing: 5) {
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(component.category)
                  .font(.subheadline.weight(.semibold))
                Text(component.macroCategory)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Text(component.inflationRate, format: .number.precision(.fractionLength(1)))
                .font(.subheadline.weight(.semibold).monospacedDigit())
              + Text("%")
            }
            ProgressView(value: component.weight, total: 100)
            HStack {
              Text(component.spend, format: .currency(code: response.currency).precision(.fractionLength(0)))
              Spacer()
              Text("\(component.weight.formatted(.number.precision(.fractionLength(1))))% of mapped spend")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
          }
          .accessibilityElement(children: .combine)
        }
      }
      .padding()
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
  }
}

#Preview {
  NavigationStack {
    PersonalInflationScreen()
  }
}
