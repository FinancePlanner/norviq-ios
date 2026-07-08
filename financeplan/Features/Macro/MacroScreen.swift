import SwiftUI
import StockPlanShared
import Factory

/// Starter Macro / Inflation screen (Nowflation-style).
/// Phase 1: Hero gauge + notes + Top Movers (Utilities/Food/Shelter) + simple components list.
struct MacroScreen: View {
  @State private var viewModel = MacroViewModel()
  @State private var topMovers: [TopMoverDTO] = []
  @State private var selectedCountry: String = "US"

  private let countries = ["US", "BR", "PT"]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Country switcher (demo)
        Picker("Country", selection: $selectedCountry) {
          Text("🇺🇸 US").tag("US")
          Text("🇧🇷 Brazil").tag("BR")
          Text("🇵🇹 Portugal").tag("PT")
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedCountry) { _, newValue in
          Task {
            await viewModel.load(country: newValue)
            topMovers = await viewModel.topMoversForFocus(country: newValue)
          }
        }

        if let s = viewModel.snapshot {
          // Hero
          VStack(alignment: .leading, spacing: 8) {
            Text("Inflation Today — \(s.country)")
              .font(.title2.bold())

            HStack(alignment: .firstTextBaseline, spacing: 12) {
              Text("\(s.headline.nowValue, specifier: "%.2f")%")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.tint)

              VStack(alignment: .leading, spacing: 2) {
                Text(s.headline.name)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                if let gap = s.headline.gap {
                  Text("vs official \(s.headline.officialValue ?? 0, specifier: "%.1f")%  •  \(gap > 0 ? "+" : "")\(gap, specifier: "%.2f")pp")
                    .font(.caption)
                    .foregroundStyle(gap < 0 ? .green : .red)
                }
              }
            }

            if let notes = s.notes {
              Text(notes)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Text("As of \(s.asOf) • \(s.source) • \(s.currency)")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
          .padding()
          .background(.thinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 16))

          // Top Movers
          VStack(alignment: .leading, spacing: 8) {
            Text("Top Movers")
              .font(.headline)

            ForEach(topMovers.isEmpty ? s.topMovers : topMovers) { mover in
              HStack {
                Text(mover.category)
                Spacer()
                Text("\(mover.changeYoY, specifier: "%+.2f")% YoY")
                  .foregroundStyle((mover.changeYoY >= 0) ? .green : .red)
              }
              .padding(.vertical, 4)
            }
            Text("Focus: Utilities • Food • Shelter (tap to expand)")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .padding()
          .background(.thinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 16))

          // Gauges summary
          VStack(alignment: .leading, spacing: 6) {
            Text("Gauges")
              .font(.headline)
            ForEach(s.gauges, id: \.name) { g in
              HStack {
                Text(g.name)
                Spacer()
                Text("\(g.nowValue, specifier: "%.2f")%")
                  .fontWeight(.semibold)
              }
              .font(.callout)
            }
          }
          .padding()
          .background(.thinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 16))

          // Key Components
          VStack(alignment: .leading, spacing: 6) {
            Text("Key Components (YoY)")
              .font(.headline)
            ForEach(s.components.prefix(8)) { c in
              HStack {
                Text(c.category)
                Spacer()
                Text("\(c.ourYoY, specifier: "%+.1f")%")
                  .foregroundStyle(c.ourYoY >= 0 ? .primary : .green)
              }
              .font(.callout)
            }
          }
          .padding()
          .background(.thinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 16))

        } else if viewModel.isLoading {
          ProgressView("Loading inflation data…")
            .padding()
        } else if let err = viewModel.errorMessage {
          Text("Failed to load: \(err)")
            .foregroundStyle(.red)
        } else {
          Button("Load Inflation Data") {
            Task { await viewModel.load() }
          }
        }
      }
      .padding()
    }
    .navigationTitle("Inflation")
    .task {
      if viewModel.snapshot == nil {
        await viewModel.load(country: selectedCountry)
        topMovers = await viewModel.topMoversForFocus(country: selectedCountry)
      }
    }
  }
}

#Preview {
  NavigationStack {
    MacroScreen()
  }
}
