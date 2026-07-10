import Factory
import StockPlanShared
import SwiftUI

/// Macro / Inflation screen (Nowflation-style).
/// Hero gauge + trend chart + Fed Watch (US) + Top Movers + everyday items +
/// gauges + component breakdown, country-aware.
struct MacroScreen: View {
  @State private var viewModel = MacroViewModel()
  @State private var selectedCountry: String = "US"

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        countryPicker

        if let snapshot = viewModel.snapshot {
          MacroHeroCard(snapshot: snapshot)

          if !viewModel.chartPoints.isEmpty {
            MacroTrendChartCard(
              points: viewModel.chartPoints,
              seriesName: viewModel.chartSeriesName
            )
          }

          if let fedWatch = viewModel.fedWatch {
            FedWatchCard(fedWatch: fedWatch)
          }

          MacroTopMoversCard(movers: viewModel.topMovers)

          if !viewModel.items.isEmpty {
            MacroItemsCard(items: viewModel.items)
          }

          MacroGaugesCard(gauges: snapshot.gauges)
          MacroComponentsCard(components: snapshot.components)
        } else if viewModel.isLoading {
          ProgressView("Loading inflation data…")
            .frame(maxWidth: .infinity)
            .padding()
        } else if let error = viewModel.errorMessage {
          ContentUnavailableView(
            "Couldn't load inflation data",
            systemImage: "chart.line.downtrend.xyaxis",
            description: Text(error)
          )
        }
      }
      .padding()
    }
    .navigationTitle("Inflation")
    .refreshable {
      await viewModel.load(country: selectedCountry)
    }
    .task {
      if viewModel.snapshot == nil {
        await viewModel.load(country: selectedCountry)
      }
    }
  }

  private var countryPicker: some View {
    Picker("Country", selection: $selectedCountry) {
      Text("🇺🇸 US").tag("US")
      Text("🇧🇷 Brazil").tag("BR")
      Text("🇵🇹 Portugal").tag("PT")
      Text("🇪🇺 Euro Area").tag("EA")
    }
    .pickerStyle(.segmented)
    .onChange(of: selectedCountry) { _, newValue in
      Task { await viewModel.load(country: newValue) }
    }
  }
}

// MARK: - Cards

private struct MacroHeroCard: View {
  let snapshot: InflationSnapshotResponse

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Inflation Today — \(snapshot.country)")
        .font(.title2.bold())

      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text("\(snapshot.headline.nowValue, specifier: "%.2f")%")
          .font(.system(size: 48, weight: .bold, design: .rounded))
          .foregroundStyle(.tint)
          .contentTransition(.numericText(value: snapshot.headline.nowValue))
          .appAnimation(AppMotion.state, value: snapshot.headline.nowValue)

        VStack(alignment: .leading, spacing: 2) {
          Text(snapshot.headline.name)
            .font(.caption)
            .foregroundStyle(.secondary)
          if let gap = snapshot.headline.gap {
            Text("vs official \(snapshot.headline.officialValue ?? 0, specifier: "%.1f")%  •  \(gap > 0 ? "+" : "")\(gap, specifier: "%.2f")pp")
              .font(.caption)
              .foregroundStyle(gap < 0 ? .green : .red)
          }
        }
      }

      if let countdown = snapshot.nextPrintCountdown, let days = countdown.daysRemaining {
        Label("Next CPI print in \(days) day\(days == 1 ? "" : "s")", systemImage: "calendar.badge.clock")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let notes = snapshot.notes {
        Text(notes)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Text("As of \(snapshot.asOf) • \(snapshot.source) • \(snapshot.currency)")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

private struct MacroTrendChartCard: View {
  let points: [MetricSeriesPoint]
  let seriesName: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Trend")
        .font(.headline)
      if let seriesName {
        Text("\(seriesName.replacingOccurrences(of: "_", with: " ").capitalized) • YoY % • last \(MacroViewModel.chartMonths) months")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      MetricTrendChart(points: points, format: .decimal(2))
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

private struct FedWatchCard: View {
  let fedWatch: FedWatchResponse

  private var stanceColor: Color {
    switch fedWatch.stance {
    case "restrictive": return .red
    case "accommodative": return .green
    default: return .orange
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("Fed Watch", systemImage: "building.columns")
          .font(.headline)
        Spacer()
        if let stance = fedWatch.stance {
          Text(stance.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(stanceColor.opacity(0.15), in: Capsule())
            .foregroundStyle(stanceColor)
        }
      }

      indicatorRow(
        title: "Core PCE (target \(String(format: "%.0f", fedWatch.fedTarget))%)",
        value: fedWatch.corePCE.value,
        detail: "\(fedWatch.distanceToTarget > 0 ? "+" : "")\(String(format: "%.2f", fedWatch.distanceToTarget))pp vs target",
        detailColor: fedWatch.distanceToTarget > 0 ? .red : .green
      )
      if let trimmed = fedWatch.trimmedMeanCPI {
        indicatorRow(title: trimmed.name, value: trimmed.value)
      }
      if let twoYear = fedWatch.treasury2Y {
        indicatorRow(title: twoYear.name, value: twoYear.value)
      }
      if let tenYear = fedWatch.treasury10Y {
        indicatorRow(
          title: tenYear.name,
          value: tenYear.value,
          detail: fedWatch.spread10Y2Y.map { "10Y–2Y \($0 > 0 ? "+" : "")\(String(format: "%.2f", $0))pp" }
        )
      }
      if let real = fedWatch.real10Y {
        indicatorRow(title: real.name, value: real.value)
      }

      if let meeting = fedWatch.nextFOMC {
        Divider()
        Label(
          "Next FOMC \(meeting.startDate) • in \(meeting.daysRemaining) day\(meeting.daysRemaining == 1 ? "" : "s")",
          systemImage: "calendar"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Text("Source: \(fedWatch.source) • as of \(fedWatch.asOf)")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }

  private func indicatorRow(title: String, value: Double, detail: String? = nil, detailColor: Color = .secondary) -> some View {
    HStack {
      Text(title)
        .font(.callout)
      Spacer()
      VStack(alignment: .trailing, spacing: 1) {
        Text("\(value, specifier: "%.2f")%")
          .font(.callout.weight(.semibold))
        if let detail {
          Text(detail)
            .font(.caption2)
            .foregroundStyle(detailColor)
        }
      }
    }
  }
}

private struct MacroTopMoversCard: View {
  let movers: [TopMoverDTO]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Top Movers")
        .font(.headline)

      ForEach(movers) { mover in
        HStack {
          if let direction = mover.direction {
            Image(systemName: direction == "down" ? "arrow.down.right" : (direction == "flat" ? "minus" : "arrow.up.right"))
              .font(.caption)
              .foregroundStyle(direction == "down" ? .green : .red)
          }
          Text(mover.category)
          Spacer()
          Text("\(mover.changeYoY, specifier: "%+.2f")% YoY")
            .foregroundStyle(mover.changeYoY >= 0 ? .red : .green)
            .fontWeight(.medium)
        }
        .font(.callout)
        .padding(.vertical, 4)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

private struct MacroItemsCard: View {
  let items: [MacroItemDTO]

  private let columns = [GridItem(.flexible()), GridItem(.flexible())]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Everyday Prices")
        .font(.headline)

      LazyVGrid(columns: columns, spacing: 10) {
        ForEach(items) { item in
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
              if let emoji = item.emoji {
                Text(emoji)
              }
              Text(item.name)
                .font(.caption)
                .lineLimit(2)
            }
            if let price = item.latestPrice {
              Text(price, format: .currency(code: item.currency).precision(.fractionLength(2)))
                .font(.callout.weight(.semibold))
            } else if let yoy = item.changeYoY {
              Text("\(yoy, specifier: "%+.1f")% YoY")
                .font(.callout.weight(.semibold))
                .foregroundStyle(yoy >= 0 ? .red : .green)
            }
            if item.latestPrice != nil, let yoy = item.changeYoY {
              Text("\(yoy, specifier: "%+.1f")% YoY")
                .font(.caption2)
                .foregroundStyle(yoy >= 0 ? .red : .green)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(10)
          .background(Color.primary.opacity(0.04))
          .clipShape(RoundedRectangle(cornerRadius: 10))
        }
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

private struct MacroGaugesCard: View {
  let gauges: [InflationGaugeDTO]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Gauges")
        .font(.headline)
      ForEach(gauges, id: \.name) { gauge in
        HStack {
          Text(gauge.name)
          Spacer()
          Text("\(gauge.nowValue, specifier: "%.2f")%")
            .fontWeight(.semibold)
        }
        .font(.callout)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

private struct MacroComponentsCard: View {
  let components: [InflationComponentDTO]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Key Components (YoY)")
        .font(.headline)
      ForEach(components.prefix(10)) { component in
        HStack {
          Text(component.category)
          Spacer()
          if let weight = component.cpiWeight {
            Text("w \(weight, specifier: "%.1f")%")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
          Text("\(component.ourYoY, specifier: "%+.1f")%")
            .foregroundStyle(component.ourYoY >= 0 ? Color.primary : Color.green)
            .frame(minWidth: 56, alignment: .trailing)
        }
        .font(.callout)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

#Preview {
  NavigationStack {
    MacroScreen()
  }
}
