import SwiftUI

/// Hub countries for housing / growth / policy (inflation may also offer PT).
enum EconomyCountry: String, CaseIterable, Identifiable {
  case us = "US"
  case br = "BR"
  case ea = "EA"

  var id: String { rawValue }

  var label: String {
    switch self {
    case .us: return String(localized: "US")
    case .br: return String(localized: "Brazil")
    case .ea: return String(localized: "Euro Area")
    }
  }

  var pickerLabel: String {
    switch self {
    case .us: return "🇺🇸 US"
    case .br: return "🇧🇷 BR"
    case .ea: return "🇪🇺 EA"
    }
  }
}

struct EconomyCountryPicker: View {
  @Binding var selection: String

  var body: some View {
    Picker("Country", selection: $selection) {
      ForEach(EconomyCountry.allCases) { country in
        Text(country.pickerLabel).tag(country.rawValue)
      }
    }
    .pickerStyle(.segmented)
    .accessibilityIdentifier("economy.countryPicker")
  }
}
