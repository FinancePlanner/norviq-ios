import SwiftUI

enum EconomyHubSection: String, CaseIterable, Identifiable, Hashable {
  case inflation
  case personalInflation
  case housing
  case growth
  case policy

  var id: String { rawValue }

  var title: String {
    switch self {
    case .inflation: return String(localized: "Inflation")
    case .personalInflation: return String(localized: "Your Inflation")
    case .housing: return String(localized: "Housing")
    case .growth: return String(localized: "Growth & Jobs")
    case .policy: return String(localized: "Policy Watch")
    }
  }

  var systemImage: String {
    switch self {
    case .inflation: return "chart.line.uptrend.xyaxis"
    case .personalInflation: return "person.crop.circle.badge.chart.bar"
    case .housing: return "house.fill"
    case .growth: return "briefcase.fill"
    case .policy: return "building.columns"
    }
  }

  var subtitle: String {
    switch self {
    case .inflation: return String(localized: "CPI gauges, movers, and everyday prices")
    case .personalInflation: return String(localized: "Your spending-weighted cost-of-living rate")
    case .housing: return String(localized: "Prices, rents, mortgages, and supply")
    case .growth: return String(localized: "Jobs, GDP, and recession risk")
    case .policy: return String(localized: "Central bank stance and rates")
    }
  }
}

/// Top-level Economy tab root: Inflation | Housing | Growth & Jobs | Policy Watch.
struct EconomyHubScreen: View {
  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(EconomyHubSection.allCases) { section in
            NavigationLink(value: section) {
              Label {
                VStack(alignment: .leading, spacing: 2) {
                  Text(section.title)
                    .font(.body.weight(.semibold))
                  Text(section.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              } icon: {
                Image(systemName: section.systemImage)
                  .foregroundStyle(.tint)
              }
            }
            .accessibilityIdentifier("economy.section.\(section.rawValue)")
          }
        } footer: {
          Text("Macro snapshots for US, Brazil, and Euro Area. Inflation also supports Portugal.")
            .font(.caption)
        }
      }
      .navigationTitle("Economy")
      .navigationDestination(for: EconomyHubSection.self) { section in
        switch section {
        case .inflation:
          MacroScreen()
        case .personalInflation:
          PersonalInflationScreen()
        case .housing:
          HousingHubScreen()
        case .growth:
          EconomyGrowthScreen()
        case .policy:
          PolicyWatchScreen()
        }
      }
      .accessibilityIdentifier("economy.hub")
    }
  }
}

#Preview {
  EconomyHubScreen()
}
